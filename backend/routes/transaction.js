const express = require('express');
const mongoose = require('mongoose');
const Transaction = require('../models/Transaction');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');
const generateResi = require('../utils/resiGenerator');
const { canRoleSetStatus } = require('../utils/statusValidator');

const router = express.Router();

router.post('/', auth, rbac('admin_cabang', 'super_admin'), async (req, res) => {
  try {
    const { pengirim, penerima, paket, catatan, lokasi_penerima } = req.body;
    if (!pengirim || !penerima || !paket) {
      return res.status(400).json({ message: 'Data pengirim, penerima, dan paket wajib diisi' });
    }

    const Cabang = require('../models/Cabang');
    const cabang = await Cabang.findById(req.user.cabang_id);
    if (!cabang) return res.status(400).json({ message: 'Cabang tidak ditemukan' });

    const kodeGerai = cabang.kode;
    const createdBy = {
      user_id: req.user._id,
      name: req.user.name,
      role: 'admin_cabang',
      cabang_id: req.user.cabang_id,
      cabang_name: cabang.name,
    };
    const lokasi = { nama: cabang.name, tipe: 'cabang', cabang_id: req.user.cabang_id };

    const no_resi = await generateResi(kodeGerai);

    const transaction = new Transaction({
      no_resi,
      kode_gerai: kodeGerai,
      barcode_data: no_resi,
      current_cabang_id: req.user.cabang_id,
      pengirim,
      penerima,
      lokasi_penerima: lokasi_penerima || null,
      paket: {
        berat_kg: paket.berat_kg,
        jumlah_koli: paket.jumlah_koli,
        biaya_kirim: paket.biaya_kirim,
      },
      created_by: createdBy,
      status_saat_ini: 'diterima_cabang',
      tracking_logs: [{
        status: 'diterima_cabang',
        deskripsi: `Paket diterima di ${lokasi.nama}`,
        pelaku: { user_id: req.user._id, name: req.user.name, role: req.user.role },
        lokasi,
        timestamp: new Date(),
      }],
    });

    await transaction.save();
    res.status(201).json(transaction);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/batch-status', auth, async (req, res) => {
  try {
    const { no_resi_list, status_baru, driver_user_id, tipe_tujuan, cabang_tujuan_id, nama_driver_manual, cabang_nama_manual, catatan, nama_penerima } = req.body;
    if (!no_resi_list || !no_resi_list.length || !status_baru) {
      return res.status(400).json({ message: 'no_resi_list dan status_baru wajib diisi' });
    }

    // Validasi role sekali di awal
    if (!canRoleSetStatus(req.user.role, status_baru)) {
      return res.status(403).json({ message: `Role ${req.user.role} tidak memiliki akses untuk status ${status_baru}` });
    }

    const transactions = await Transaction.find({ no_resi: { $in: no_resi_list } }).lean();
    const txMap = new Map(transactions.map(tx => [tx.no_resi, tx]));

    let driver = null;
    let cabangTujuan = null;

    if (status_baru === 'keluar_cabang' && driver_user_id) {
      driver = await (require('../models/User')).findById(driver_user_id).lean();
      if (!driver) return res.status(400).json({ message: 'Driver tidak ditemukan' });
    }
    if (status_baru === 'keluar_cabang' && tipe_tujuan === 'cabang' && cabang_tujuan_id) {
      cabangTujuan = await (require('../models/Cabang')).findById(cabang_tujuan_id).lean();
      if (!cabangTujuan) return res.status(400).json({ message: 'Cabang tujuan tidak ditemukan' });
    }

    const hasAnyDriver = driver || (nama_driver_manual && nama_driver_manual.trim().length > 0);
    const finalStatus = (status_baru === 'keluar_cabang' && hasAnyDriver) ? 'proses_kirim' : status_baru;

    // Ambil lokasi user SEKALI di luar loop
    const userLokasi = await getLokasiForUser(req.user);

    // Build Map untuk O(1) lookup
    const results = [];
    const resultsMap = new Map();
    const validTxMap = new Map();

    const pushResult = (no_resi, status, error) => {
      const item = { no_resi, status, ...(error && { error }) };
      results.push(item);
      if (status === 'ok') resultsMap.set(no_resi, item);
      return item;
    };

    for (const no_resi of no_resi_list) {
      const tx = txMap.get(no_resi);
      if (!tx) {
        pushResult(no_resi, 'error', 'Transaksi tidak ditemukan');
        continue;
      }

      if (tx.status_saat_ini === finalStatus) {
        pushResult(no_resi, 'error', `Barang ${no_resi} sudah discan sebelumnya`);
        continue;
      }

      if (status_baru === 'keluar_cabang') {
        const hasDriver = driver || (nama_driver_manual && nama_driver_manual.trim().length > 0);
        const hasTujuan = (tipe_tujuan === 'penerima') || (tipe_tujuan === 'cabang' && (cabangTujuan || (cabang_nama_manual && cabang_nama_manual.trim().length > 0)));
        if (!hasDriver || !tipe_tujuan || !hasTujuan) {
          pushResult(no_resi, 'error', 'Driver dan tujuan wajib diisi');
          continue;
        }
      }

      if (status_baru === 'diterima' && req.user.role === 'driver') {
        if (tx.driver_user_id?.toString() !== req.user._id.toString()) {
          pushResult(no_resi, 'error', 'Anda bukan driver yang bertugas untuk transaksi ini');
          continue;
        }
      }

      pushResult(no_resi, 'ok');
      validTxMap.set(tx._id.toString(), tx);
    }

    const validIds = [...validTxMap.keys()];
    let manifest = null;
    let no_manifest = null;
    const berhasilCount = validIds.length;

    if (status_baru === 'keluar_cabang' && berhasilCount > 0) {
      const generateNoManifest = require('../utils/manifestGenerator');
      no_manifest = await generateNoManifest();
    }

    if (validIds.length > 0) {
      const bulkOps = [];

      for (const [txIdStr, tx] of validTxMap) {
        const log = {
          status: status_baru,
          pelaku: { user_id: req.user._id, name: req.user.name, role: req.user.role },
          lokasi: userLokasi,
          timestamp: new Date(),
        };

        const setFields = { status_saat_ini: status_baru, updatedAt: new Date(), updated_at: new Date() };
        const pushLogs = [log];

        if (status_baru === 'keluar_cabang') {
          log.no_manifest = no_manifest;
          setFields.no_manifest = no_manifest;
          // current_cabang_id null — barang dalam perjalanan, belum sampai tujuan
          setFields.current_cabang_id = null;

          const driverName = driver ? driver.name : (nama_driver_manual || '');
          const driverPhone = driver ? driver.phone : '';
          const driverId = driver ? driver._id : null;

          if (driverName) {
            setFields.nama_driver = driverName;
            setFields.kontak_driver = driverPhone || null;
            setFields.driver_user_id = driverId;
            log.driver_ditugaskan = { user_id: driverId, nama: driverName, kontak: driverPhone || '' };
          }

          if (tipe_tujuan === 'cabang') {
            const cabangName = cabangTujuan ? cabangTujuan.name : (cabang_nama_manual || '');
            if (cabangName) {
              setFields.tujuan_selanjutnya = { tipe: 'cabang', cabang_id: cabangTujuan ? cabangTujuan._id : null, nama: cabangName };
              log.tujuan = { tipe: 'cabang', nama: cabangName };
              const dariLokasi = userLokasi.nama || 'lokasi';
              log.deskripsi = `Paket keluar dari ${dariLokasi} menuju ${cabangName}${driverName ? `, dibawa oleh ${driverName}` : ''}`;

              if (driverName) {
                const autoLog = {
                  status: 'proses_kirim',
                  deskripsi: `Paket dalam perjalanan oleh ${driverName} menuju ${cabangName}`,
                  pelaku: { name: 'Sistem', role: 'system' },
                  tujuan: { tipe: 'cabang', nama: cabangName },
                  no_manifest: no_manifest,
                  timestamp: new Date(Date.now() + 1),
                };
                pushLogs.push(autoLog);
                setFields.status_saat_ini = 'proses_kirim';
              }
            }
          } else if (tipe_tujuan === 'penerima') {
            setFields.tujuan_selanjutnya = { tipe: 'penerima', nama: tx.penerima.name };
            log.tujuan = { tipe: 'penerima', nama: tx.penerima.name };
            const dariLokasi = userLokasi.nama || 'lokasi';
            log.deskripsi = `Paket keluar dari ${dariLokasi}, diantar langsung ke ${tx.penerima.name}${driverName ? ` oleh ${driverName}` : ''}`;

            if (driverName) {
              const autoLog = {
                status: 'proses_kirim',
                deskripsi: `Paket dalam perjalanan oleh ${driverName} menuju alamat penerima`,
                pelaku: { name: 'Sistem', role: 'system' },
                tujuan: { tipe: 'penerima', nama: tx.penerima.name },
                no_manifest: no_manifest,
                timestamp: new Date(Date.now() + 1),
              };
              pushLogs.push(autoLog);
              setFields.status_saat_ini = 'proses_kirim';
            }
          }
        } else if (status_baru === 'diterima_cabang') {
          setFields.current_cabang_id = userLokasi?.cabang_id || null;
          log.deskripsi = `Paket diterima di ${userLokasi.nama}`;
        } else if (status_baru === 'diterima') {
          setFields.current_cabang_id = null;
          const namaPenerimaFinal = nama_penerima || tx.penerima.name;
          log.nama_penerima = namaPenerimaFinal;
          log.deskripsi = `Paket telah diterima oleh ${namaPenerimaFinal}${catatan ? ` (${catatan})` : ''}`;
          setFields.nama_penerima_akhir = namaPenerimaFinal;
        }

        bulkOps.push({
          updateOne: {
            filter: { _id: new mongoose.Types.ObjectId(txIdStr), status_saat_ini: tx.status_saat_ini },
            update: { $set: setFields, $push: { tracking_logs: { $each: pushLogs } } },
          },
        });
      }

      const bulkResult = await Transaction.bulkWrite(bulkOps, { ordered: false });

      // Deteksi conflict pakai matchedCount — 1 query tambahan cuma kalau mismatch
      if (bulkResult.matchedCount < validIds.length) {
        const currentDocs = await Transaction.find(
          { _id: { $in: validIds } },
          { _id: 1, no_resi: 1, status_saat_ini: 1 }
        ).lean();

        for (const doc of currentDocs) {
          const tx = validTxMap.get(doc._id.toString());
          if (tx && tx.status_saat_ini !== doc.status_saat_ini) {
            const r = resultsMap.get(tx.no_resi);
            if (r) {
              r.status = 'error';
              r.error = `Barang ${tx.no_resi} sudah discan oleh admin lain`;
            }
          }
        }
      }

      // — UPDATE MANIFEST STATUS AFTER DITERIMA / DITERIMA_CABANG —
      if (status_baru === 'diterima_cabang' || status_baru === 'diterima') {
        // Cari no_manifest dari field transaksi atau tracking_logs (fallback)
        const updatedTxList = await Transaction.find(
          { _id: { $in: validIds } },
          { no_manifest: 1, tracking_logs: 1 }
        ).lean();
        const manifestNos = [...new Set(
          updatedTxList.map(tx => {
            // Prioritas 1: field no_manifest di transaksi
            if (tx.no_manifest) return tx.no_manifest;
            // Prioritas 2: cari di semua tracking_logs yang punya no_manifest
            if (tx.tracking_logs?.length > 0) {
              const logWithManifest = tx.tracking_logs.find(l => l.no_manifest);
              if (logWithManifest?.no_manifest) return logWithManifest.no_manifest;
            }
            return null;
          }).filter(Boolean)
        )];

        if (manifestNos.length > 0) {
          const Manifest = require('../models/Manifest');
          for (const nm of manifestNos) {
            const remaining = await Transaction.countDocuments({
              no_manifest: nm,
              status_saat_ini: { $nin: ['diterima', 'diterima_cabang'] },
            });
            if (remaining === 0) {
              await Manifest.findOneAndUpdate(
                { no_manifest: nm },
                { status: 'selesai', completed_at: new Date() },
              );
            } else {
              await Manifest.findOneAndUpdate(
                { no_manifest: nm, status: { $ne: 'selesai' } },
                { status: 'dalam_perjalanan' },
              );
            }
          }
        }
      }

      // — CREATE MANIFEST DOCUMENT & SET NO_MANIFEST —
      if (status_baru === 'keluar_cabang' && no_manifest && berhasilCount > 0) {
        const tipeManifest = tipe_tujuan === 'cabang' ? 'antar_cabang' : 'antar_penerima';
        const workUnit = tipe_tujuan === 'cabang' ? 1 : berhasilCount;

        let totalBerat = 0;
        let totalKoli = 0;
        for (const [, tx] of validTxMap) {
          totalBerat += tx.paket?.berat_kg || 0;
          totalKoli += tx.paket?.jumlah_koli || 0;
        }

        const Manifest = require('../models/Manifest');
        manifest = await Manifest.create({
          no_manifest,
          created_by: {
            user_id: req.user._id,
            name: req.user.name,
            cabang_id: req.user.cabang_id,
            cabang_name: userLokasi?.nama || '',
            cabang_phone: userLokasi?.phone || '',
          },
          driver: {
            user_id: driver?._id || null,
            name: driver?.name || nama_driver_manual || '',
            phone: driver?.phone || '',
          },
          tujuan: {
            tipe: tipe_tujuan,
            cabang_id: cabangTujuan?._id || null,
            nama: tipe_tujuan === 'cabang'
              ? (cabangTujuan?.name || cabang_nama_manual || '')
              : 'Langsung ke Penerima',
            lokasi: tipe_tujuan === 'cabang' && cabangTujuan?.lokasi
              ? cabangTujuan.lokasi
              : undefined,
          },
          asal_cabang_id: req.user.cabang_id,
          asal_cabang_name: userLokasi?.nama || '',
          tipe_manifest: tipeManifest,
          work_unit: workUnit,
          total_resi: berhasilCount,
          jumlah_koli: totalKoli,
          total_berat: totalBerat,
          status: 'dibuat',
        });

        // Update no_manifest di setiap transaksi
        await Transaction.updateMany(
          { _id: { $in: validIds } },
          { $set: { no_manifest } },
        );
      }
    }

    res.json({
      success: results.every(r => r.status === 'ok'),
      total: no_resi_list.length,
      berhasil: results.filter(r => r.status === 'ok').length,
      gagal: results.filter(r => r.status === 'error').length,
      results,
      manifest: manifest ? {
        _id: manifest._id,
        no_manifest: manifest.no_manifest,
        total_resi: manifest.total_resi,
        tipe_manifest: manifest.tipe_manifest,
        work_unit: manifest.work_unit,
        jumlah_koli: manifest.jumlah_koli,
        total_berat: manifest.total_berat,
        driver: manifest.driver,
        tujuan: manifest.tujuan,
      } : null,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    const { status, search, kode_gerai, page = 1, limit = 20, start_date, end_date } = req.query;
    const filter = {};

    if (req.user.role === 'admin_cabang') {
      const cabangId = new mongoose.Types.ObjectId(req.user.cabang_id);
      const tab = req.query.tab || 'current';

      if (tab === 'history') {
        filter['tracking_logs.lokasi.cabang_id'] = cabangId;
        filter.current_cabang_id = { $ne: cabangId };
      } else {
        filter.current_cabang_id = cabangId;
      }
    } else if (req.user.role === 'driver') {
      const tab = req.query.tab || 'current';
      if (tab === 'history') {
        filter['tracking_logs.driver_ditugaskan.user_id'] = req.user._id;
        // Jangan tampilkan transaksi yang sedang aktif dipegang driver ini
        filter.$nor = [
          { driver_user_id: req.user._id, status_saat_ini: 'proses_kirim' },
        ];
      } else {
        filter.driver_user_id = req.user._id;
      }
      if (status) {
        const statusArr = status.split(',').map(s => s.trim());
        filter.status_saat_ini = { $in: statusArr };
      }
    } else {
      if (status) {
        const statusArr = status.split(',').map(s => s.trim());
        filter.status_saat_ini = { $in: statusArr };
      }
    }

    if (search) {
      const upper = search.toUpperCase();
      filter.$or = [
        { no_resi: { $regex: `^${upper}` } },
        { barcode_data: { $regex: `^${upper}` } },
      ];
    }

    if (kode_gerai) filter.kode_gerai = kode_gerai;

    if (start_date || end_date) {
      filter.createdAt = {};
      if (start_date) filter.createdAt.$gte = new Date(start_date);
      if (end_date) {
        const d = new Date(end_date);
        d.setHours(23, 59, 59, 999);
        filter.createdAt.$lte = d;
      }
    }

    const total = await Transaction.countDocuments(filter);
    const sortField = req.query.tab === 'history' ? { 'tracking_logs.timestamp': -1 } : { createdAt: -1 };
    const data = await Transaction.find(filter)
      .sort(sortField)
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .lean();

    res.json({ data, total, page: parseInt(page), totalPages: Math.ceil(total / limit) });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.delete('/:id', auth, rbac('admin_cabang', 'super_admin'), async (req, res) => {
  try {
    const tx = await Transaction.findById(req.params.id);
    if (!tx) return res.status(404).json({ message: 'Transaksi tidak ditemukan' });

    if (tx.created_by?.user_id?.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Anda hanya bisa menghapus transaksi yang dibuat sendiri' });
    }

    await Transaction.findByIdAndDelete(req.params.id);
    res.json({ message: 'Transaksi berhasil dihapus' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

async function getLokasiForUser(user) {
  if (user.cabang_id) {
    const Cabang = require('../models/Cabang');
    const cabang = await Cabang.findById(user.cabang_id).lean();
    return cabang
      ? { nama: cabang.name, tipe: 'cabang', cabang_id: cabang._id, phone: cabang.phone || '' }
      : { nama: '', tipe: '', cabang_id: null, phone: '' };
  }
  return { nama: '', tipe: '', cabang_id: null, phone: '' };
}

module.exports = router;