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
    const { pengirim, penerima, paket, catatan, lokasi_penerima, jenis_pembayaran } = req.body;
    if (!pengirim || !penerima || !paket) {
      return res.status(400).json({ message: 'Data pengirim, penerima, dan paket wajib diisi' });
    }

    const pembayaran = (jenis_pembayaran && ['cash', 'cod', 'tempo'].includes(jenis_pembayaran))
      ? jenis_pembayaran
      : 'cash';
    const statusPembayaran = pembayaran === 'cash' ? 'paid' : 'unpaid';
    const tempoHari = req.body.tempo_hari != null ? parseInt(req.body.tempo_hari) : 14;

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

    // COD walk-in yang dibuat admin cabang: cabang pembuat = last mile
    // penerima COD, sehingga muncul di manajemen pembayaran COD cabang tsb.
    const cod_cabang_id = pembayaran === 'cod' && req.user.role === 'admin_cabang'
      ? req.user.cabang_id
      : null;

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
      jenis_pembayaran: pembayaran,
      status_pembayaran: statusPembayaran,
      tempo_hari: tempoHari,
      cod_cabang_id,
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

      // Safety: barang hilang tidak boleh diproses lewat scan biasa
      if (tx.jenis_masalah === 'hilang' && (status_baru === 'keluar_cabang' || status_baru === 'diterima_cabang' || status_baru === 'diterima')) {
        pushResult(no_resi, 'error', 'Barang hilang tidak dapat diproses, selesaikan kasus terlebih dahulu');
        continue;
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
            setFields.cod_cabang_id = userLokasi?.cabang_id || null;

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

          // COD diambil walk-in di cabang ini → cabang penerima = last mile aktual
          // yang berhak konfirmasi lunas COD (bukan cabang asal pengirim).
          if (tx.jenis_pembayaran === 'cod' && userLokasi?.cabang_id) {
            setFields.cod_cabang_id = userLokasi.cabang_id;
          }

          // Jika serah terima retur (gagal_kirim diterima oleh pengirim walk-in), auto selesai
          if (tx.jenis_masalah === 'gagal_kirim') {
            setFields.status_saat_ini = 'kasus_selesai';
            setFields.diselesaikan_pada = new Date();
            setFields.diselesaikan_oleh = {
              user_id: req.user._id,
              name: req.user.name,
            };
            log.status = 'kasus_selesai';
            log.deskripsi = `Barang retur gagal kirim telah diterima oleh pengirim (${namaPenerimaFinal})${catatan ? ` — ${catatan}` : ''}`;
          }
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
              status_saat_ini: { $nin: ['diterima', 'diterima_cabang', 'hilang', 'gagal_kirim', 'kasus_selesai'] },
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

        // Update status manifest ke dalam_perjalanan jika ada driver
        if (hasAnyDriver) {
          await Manifest.findOneAndUpdate(
            { no_manifest },
            { status: 'dalam_perjalanan' },
          );
        }

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
    const { status, search, kode_gerai, page = 1, limit = 20, start_date, end_date, jenis_pembayaran, status_pembayaran, driver_user_id } = req.query;
    const filter = {};

    if (req.user.role === 'admin_cabang') {
      const cabangId = new mongoose.Types.ObjectId(req.user.cabang_id);
      const tab = req.query.tab || 'current';

      // Jika query jenis_pembayaran, skip filter tab default
      if (!jenis_pembayaran) {
        if (tab === 'history') {
        filter['tracking_logs.lokasi.cabang_id'] = cabangId;
        filter.current_cabang_id = { $ne: cabangId };
        filter.status_saat_ini = { $ne: 'kasus_selesai' };
      } else if (tab === 'bermasalah') {
        filter.$or = [
          { current_cabang_id: cabangId, status_saat_ini: { $in: ['hilang', 'gagal_kirim', 'kasus_selesai'] } },
          { jenis_masalah: 'gagal_kirim', 'dilaporkan_oleh.cabang_id': cabangId },
          { 'dilaporkan_oleh.cabang_id': cabangId, status_saat_ini: 'kasus_selesai' },
        ];
      } else {
        filter.current_cabang_id = cabangId;
        // Sembunyikan kasus yang sudah selesai dari daftar transaksi utama
        filter.status_saat_ini = { $ne: 'kasus_selesai' };
      }
      } // end if (!jenis_pembayaran)
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
      const tab = req.query.tab || '';
      if (tab === 'bermasalah') {
        filter.$or = [
          { status_saat_ini: { $in: ['hilang', 'gagal_kirim', 'kasus_selesai'] } },
          { jenis_masalah: 'gagal_kirim' },
        ];
      } else if (status) {
        const statusArr = status.split(',').map(s => s.trim());
        filter.status_saat_ini = { $in: statusArr };
      } else {
        // Default: sembunyikan barang bermasalah — hanya tampil di halaman khusus
        filter.status_saat_ini = { $nin: ['hilang', 'gagal_kirim', 'kasus_selesai'] };
      }
    }

    // Universal status filter (berlaku untuk semua role, termasuk admin_cabang)
    if (status) {
      const statusArr = status.split(',').map(s => s.trim());
      filter.status_saat_ini = { $in: statusArr };
    }

    // Driver filter
    if (driver_user_id) {
      filter.driver_user_id = new mongoose.Types.ObjectId(driver_user_id);
    }

    if (search) {
      const upper = search.toUpperCase();
      // no_resi dan barcode_data selalu identik di create (barcode_data = no_resi),
      // jadi cukup cari no_resi saja — memungkinkan MongoDB memakai unique index
      // no_resi secara langsung (range scan), tanpa $or IndexUnion overhead.
      const searchFilter = { no_resi: { $regex: `^${upper}` } };
      if (filter.$or) {
        filter.$and = [{ $or: filter.$or }, searchFilter];
        delete filter.$or;
      } else if (filter.$and) {
        filter.$and.push(searchFilter);
      } else {
        filter.no_resi = searchFilter.no_resi;
      }
    }

    if (kode_gerai) filter.kode_gerai = kode_gerai;
    if (jenis_pembayaran) filter.jenis_pembayaran = jenis_pembayaran;
    if (status_pembayaran) filter.status_pembayaran = status_pembayaran;

    // Filter COD — admin_cabang melihat transaksi di cod_cabang_id (last mile) atau gagal_kirim di cabang asal, kecuali hilang
    if (jenis_pembayaran === 'cod' && req.user.role === 'admin_cabang') {
      const codOr = [
        { cod_cabang_id: new mongoose.Types.ObjectId(req.user.cabang_id), jenis_masalah: { $nin: ['hilang', 'gagal_kirim'] } },
        { jenis_masalah: 'gagal_kirim', 'created_by.cabang_id': new mongoose.Types.ObjectId(req.user.cabang_id) },
      ];
      if (filter.$or) {
        filter.$and = [{ $or: filter.$or }, { $or: codOr }];
        delete filter.$or;
      } else {
        filter.$or = codOr;
      }
    }
    // Filter Tempo berdasarkan created_by.cabang_id untuk admin_cabang
    if (jenis_pembayaran === 'tempo' && req.user.role === 'admin_cabang') {
      filter['created_by.cabang_id'] = new mongoose.Types.ObjectId(req.user.cabang_id);
      filter.jenis_masalah = { $nin: ['hilang', 'gagal_kirim'] };
    }

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
    const sortField = req.query.tab === 'history'
      ? { 'tracking_logs.timestamp': -1 }
      : req.query.tab === 'bermasalah'
        ? { dilaporkan_pada: -1, createdAt: -1 }
        : { createdAt: -1 };
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

// GET /api/transactions/recent-contacts?cabang_id=xxx&limit=50
router.get('/recent-contacts', auth, async (req, res) => {
  try {
    const { cabang_id, limit = 500 } = req.query;
    if (!cabang_id) {
      return res.status(400).json({ error: 'cabang_id diperlukan' });
    }

    const cabangObjectId = new mongoose.Types.ObjectId(cabang_id);
    const limitNum = Math.min(parseInt(limit) || 500, 500);

    const [result] = await Transaction.aggregate([
      { $match: { 'created_by.cabang_id': cabangObjectId } },
      { $sort: { createdAt: -1 } },
      { $limit: 1000 },
      {
        $facet: {
          pengirim: [
            {
              $group: {
                _id: { name: '$pengirim.name', phone: '$pengirim.phone' },
                address: { $first: '$pengirim.address' },
                lastUsed: { $first: '$createdAt' },
                count: { $sum: 1 },
              },
            },
            { $sort: { lastUsed: -1 } },
            { $limit: limitNum },
            {
              $project: {
                _id: 0, name: '$_id.name', phone: '$_id.phone',
                address: 1, lastUsed: 1, count: 1,
              },
            },
          ],
          penerima: [
            {
              $group: {
                _id: { name: '$penerima.name', phone: '$penerima.phone' },
                address: { $first: '$penerima.address' },
                kecamatan: { $first: '$penerima.kecamatan' },
                kota: { $first: '$penerima.kota' },
                lokasi_penerima: { $first: '$lokasi_penerima' },
                lastUsed: { $first: '$createdAt' },
                count: { $sum: 1 },
              },
            },
            { $sort: { lastUsed: -1 } },
            { $limit: limitNum },
            {
              $project: {
                _id: 0, name: '$_id.name', phone: '$_id.phone',
                address: 1, kecamatan: 1, kota: 1, lokasi_penerima: 1, lastUsed: 1, count: 1,
              },
            },
          ],
          oldestDate: [
            { $group: { _id: null, oldest: { $min: '$createdAt' } } },
            { $project: { _id: 0, oldest: 1 } },
          ],
        },
      },
    ]);

    const response = result || { pengirim: [], penerima: [], oldestDate: [] };
    response.oldestDate = response.oldestDate?.[0]?.oldest || null;
    res.json(response);
  } catch (err) {
    console.error('Error mengambil recent contacts:', err);
    res.status(500).json({ error: err.message });
  }
});

router.post('/:id/laporkan-masalah', auth, rbac('admin_cabang'), async (req, res) => {
  try {
    const { jenis, catatan } = req.body;
    if (!jenis || !['hilang', 'gagal_kirim'].includes(jenis)) {
      return res.status(400).json({ message: 'Jenis masalah harus "hilang" atau "gagal_kirim"' });
    }
    if (!catatan || !catatan.trim()) {
      return res.status(400).json({ message: 'Catatan masalah wajib diisi' });
    }

    const tx = await Transaction.findById(req.params.id);
    if (!tx) return res.status(404).json({ message: 'Transaksi tidak ditemukan' });

    if (!tx.current_cabang_id || tx.current_cabang_id.toString() !== req.user.cabang_id?.toString()) {
      return res.status(403).json({ message: 'Hanya admin cabang tujuan yang dapat melaporkan masalah pada resi ini' });
    }

    if (['hilang', 'gagal_kirim', 'kasus_selesai', 'diterima'].includes(tx.status_saat_ini)) {
      return res.status(400).json({ message: `Transaksi sudah dalam status ${tx.status_saat_ini}` });
    }

    const userLokasi = await getLokasiForUser(req.user);

    const log = {
      status: jenis,
      deskripsi: `Dilaporkan ${jenis === 'hilang' ? 'hilang' : 'gagal dikirim'} oleh ${req.user.name}: ${catatan}`,
      pelaku: { user_id: req.user._id, name: req.user.name, role: req.user.role },
      lokasi: userLokasi,
      timestamp: new Date(),
    };

    tx.status_saat_ini = jenis;
    tx.jenis_masalah = jenis;
    tx.catatan_masalah = catatan;
    tx.dilaporkan_oleh = {
      user_id: req.user._id,
      name: req.user.name,
      role: req.user.role,
      cabang_id: req.user.cabang_id,
      cabang_name: userLokasi?.nama || '',
    };
    tx.dilaporkan_pada = new Date();
    tx.tracking_logs.push(log);

    if (jenis === 'gagal_kirim' && tx.created_by?.cabang_id) {
      tx.tujuan_selanjutnya = {
        tipe: 'cabang',
        cabang_id: tx.created_by.cabang_id,
        nama: tx.created_by.cabang_name || 'Cabang Asal',
      };
    }

    await tx.save();
    res.json(tx);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.put('/:id/tandai-selesai', auth, rbac('super_admin'), async (req, res) => {
  try {
    const tx = await Transaction.findById(req.params.id);
    if (!tx) return res.status(404).json({ message: 'Transaksi tidak ditemukan' });

    if (tx.status_saat_ini !== 'hilang') {
      return res.status(400).json({ message: 'Hanya transaksi hilang yang dapat ditandai selesai' });
    }

    const log = {
      status: 'kasus_selesai',
      deskripsi: `Kasus diselesaikan oleh ${req.user.name} (Super Admin)`,
      pelaku: { user_id: req.user._id, name: req.user.name, role: req.user.role },
      timestamp: new Date(),
    };

    tx.status_saat_ini = 'kasus_selesai';
    tx.current_cabang_id = null;
    tx.diselesaikan_oleh = { user_id: req.user._id, name: req.user.name };
    tx.diselesaikan_pada = new Date();
    tx.tracking_logs.push(log);

    await tx.save();
    res.json(tx);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// — BATALKAN KASUS SELESAI (revert terminal state) —
router.post('/:id/batalkan-kasus-selesai', auth, rbac('super_admin'), async (req, res) => {
  try {
    const tx = await Transaction.findById(req.params.id);
    if (!tx) return res.status(404).json({ message: 'Transaksi tidak ditemukan' });
    if (tx.status_saat_ini !== 'kasus_selesai') {
      return res.status(400).json({ message: 'Hanya transaksi kasus selesai yang dapat dibatalkan' });
    }

    const cabangId = tx.dilaporkan_oleh?.cabang_id || tx.created_by?.cabang_id;
    const cabangNama = tx.dilaporkan_oleh?.cabang_name || tx.created_by?.cabang_name || '';

    const log = {
      status: 'diterima_cabang',
      deskripsi: `Pembatalan kasus selesai oleh ${req.user.name} (Super Admin), dikembalikan ke ${cabangNama}`,
      pelaku: { user_id: req.user._id, name: req.user.name, role: req.user.role },
      lokasi: { nama: cabangNama, tipe: 'cabang', cabang_id: cabangId },
      timestamp: new Date(),
    };

    tx.status_saat_ini = 'diterima_cabang';
    tx.current_cabang_id = cabangId;
    tx.diselesaikan_oleh = null;
    tx.diselesaikan_pada = null;
    tx.jenis_masalah = null;
    tx.catatan_masalah = '';
    tx.dilaporkan_oleh = null;
    tx.dilaporkan_pada = null;
    tx.tujuan_selanjutnya = null;
    tx.nama_driver = null;
    tx.kontak_driver = null;
    tx.driver_user_id = null;
    tx.no_manifest = null;
    tx.tracking_logs.push(log);

    await tx.save();
    res.json(tx);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// — BATALKAN HILANG (barang ketemu) —
router.post('/:id/batalkan-hilang', auth, rbac('admin_cabang', 'super_admin'), async (req, res) => {
  try {
    const tx = await Transaction.findById(req.params.id);
    if (!tx) return res.status(404).json({ message: 'Transaksi tidak ditemukan' });
    if (tx.jenis_masalah !== 'hilang') {
      return res.status(400).json({ message: 'Bukan transaksi hilang' });
    }

    // admin_cabang hanya bisa batalkan milik cabangnya sendiri
    if (req.user.role === 'admin_cabang') {
      const cabangPelapor = tx.dilaporkan_oleh?.cabang_id?.toString();
      if (!cabangPelapor || cabangPelapor !== req.user.cabang_id?.toString()) {
        return res.status(403).json({ message: 'Hanya admin cabang pelapor yang dapat membatalkan' });
      }
    }

    const cabangId = tx.dilaporkan_oleh?.cabang_id || tx.created_by?.cabang_id;
    const cabangNama = tx.dilaporkan_oleh?.cabang_name || tx.created_by?.cabang_name || '';

    const log = {
      status: 'diterima_cabang',
      deskripsi: `Barang ditemukan oleh ${req.user.name} (${req.user.role === 'super_admin' ? 'Super Admin' : 'Admin Cabang'}), dikembalikan ke ${cabangNama}`,
      pelaku: { user_id: req.user._id, name: req.user.name, role: req.user.role },
      lokasi: { nama: cabangNama, tipe: 'cabang', cabang_id: cabangId },
      timestamp: new Date(),
    };

    tx.status_saat_ini = 'diterima_cabang';
    tx.current_cabang_id = cabangId;
    tx.jenis_masalah = null;
    tx.catatan_masalah = '';
    tx.dilaporkan_oleh = null;
    tx.dilaporkan_pada = null;
    tx.diselesaikan_oleh = null;
    tx.diselesaikan_pada = null;
    tx.tujuan_selanjutnya = null;
    tx.nama_driver = null;
    tx.kontak_driver = null;
    tx.driver_user_id = null;
    tx.no_manifest = null;

    tx.tracking_logs.push(log);
    await tx.save();
    res.json(tx);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// — BATALKAN GAGAL KIRIM —
router.post('/:id/batalkan-gagal-kirim', auth, rbac('admin_cabang', 'super_admin'), async (req, res) => {
  try {
    const tx = await Transaction.findById(req.params.id);
    if (!tx) return res.status(404).json({ message: 'Transaksi tidak ditemukan' });
    if (tx.jenis_masalah !== 'gagal_kirim') {
      return res.status(400).json({ message: 'Bukan transaksi gagal kirim' });
    }

    // admin_cabang hanya bisa batalkan milik cabangnya sendiri
    if (req.user.role === 'admin_cabang') {
      const cabangPelapor = tx.dilaporkan_oleh?.cabang_id?.toString();
      if (!cabangPelapor || cabangPelapor !== req.user.cabang_id?.toString()) {
        return res.status(403).json({ message: 'Hanya admin cabang pelapor yang dapat membatalkan' });
      }
    }

    const cabangId = tx.dilaporkan_oleh?.cabang_id || tx.created_by?.cabang_id;
    const cabangNama = tx.dilaporkan_oleh?.cabang_name || tx.created_by?.cabang_name || '';

    const log = {
      status: 'diterima_cabang',
      deskripsi: `Anulir gagal kirim oleh ${req.user.name} (${req.user.role === 'super_admin' ? 'Super Admin' : 'Admin Cabang'}), dikembalikan ke ${cabangNama}`,
      pelaku: { user_id: req.user._id, name: req.user.name, role: req.user.role },
      lokasi: { nama: cabangNama, tipe: 'cabang', cabang_id: cabangId },
      timestamp: new Date(),
    };

    tx.status_saat_ini = 'diterima_cabang';
    tx.current_cabang_id = cabangId;
    tx.jenis_masalah = null;
    tx.catatan_masalah = '';
    tx.dilaporkan_oleh = null;
    tx.dilaporkan_pada = null;
    tx.tujuan_selanjutnya = null;
    tx.nama_driver = null;
    tx.kontak_driver = null;
    tx.driver_user_id = null;
    tx.no_manifest = null;
    tx.diselesaikan_oleh = null;
    tx.diselesaikan_pada = null;

    tx.tracking_logs.push(log);
    await tx.save();
    res.json(tx);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// — KONFIRMASI PEMBAYARAN COD / TEMPO —
router.put('/:id/konfirmasi-pembayaran', auth, rbac('admin_cabang', 'super_admin'), async (req, res) => {
  try {
    const tx = await Transaction.findById(req.params.id);
    if (!tx) return res.status(404).json({ message: 'Transaksi tidak ditemukan' });

    if (!['cod', 'tempo'].includes(tx.jenis_pembayaran)) {
      return res.status(400).json({ message: 'Hanya transaksi COD atau Tempo yang bisa dikonfirmasi pembayarannya' });
    }
    if (tx.status_pembayaran === 'paid') {
      return res.status(400).json({ message: 'Pembayaran sudah dikonfirmasi sebelumnya' });
    }

    // Validasi RBAC berdasarkan jenis pembayaran
    if (tx.jenis_pembayaran === 'cod') {
      if (req.user.role !== 'admin_cabang') {
        return res.status(403).json({ message: 'Hanya admin cabang yang dapat mengkonfirmasi pembayaran COD' });
      }
      const isLastMile = tx.cod_cabang_id && tx.cod_cabang_id.toString() === req.user.cabang_id?.toString();
      const isCabangAsal = tx.jenis_masalah === 'gagal_kirim' &&
          tx.created_by?.cabang_id && tx.created_by.cabang_id.toString() === req.user.cabang_id?.toString();
      if (!isLastMile && !isCabangAsal) {
        return res.status(403).json({
          message: (tx.status_saat_ini === 'gagal_kirim' || tx.jenis_masalah === 'gagal_kirim')
              ? 'Hanya admin cabang last mile atau cabang asal yang dapat mengkonfirmasi pembayaran COD'
              : 'Hanya admin cabang last mile yang dapat mengkonfirmasi pembayaran COD',
        });
      }
    } else if (tx.jenis_pembayaran === 'tempo') {
      // Tempo: admin cabang asal atau super admin
      if (req.user.role === 'admin_cabang') {
        if (!tx.created_by?.cabang_id || tx.created_by.cabang_id.toString() !== req.user.cabang_id?.toString()) {
          return res.status(403).json({ message: 'Hanya admin cabang asal yang dapat mengkonfirmasi pembayaran Tempo' });
        }
      }
      // super_admin bisa semua
    }

    tx.status_pembayaran = 'paid';
    tx.pembayaran_dikonfirmasi_oleh = {
      user_id: req.user._id,
      name: req.user.name,
      role: req.user.role,
      cabang_id: req.user.cabang_id || null,
    };
    tx.pembayaran_dikonfirmasi_pada = new Date();
    await tx.save();

    res.json(tx);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// — KONFIRMASI PEMBAYARAN MASSAL (per driver / multiple ids) —
router.put('/konfirmasi-pembayaran-massal', auth, rbac('admin_cabang', 'super_admin'), async (req, res) => {
  try {
    const { ids } = req.body;
    if (!Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({ message: 'Daftar id transaksi kosong' });
    }

    const txs = await Transaction.find({ _id: { $in: ids } });
    if (txs.length === 0) {
      return res.status(404).json({ message: 'Transaksi tidak ditemukan' });
    }

    const now = new Date();
    const updated = [];
    for (const tx of txs) {
      if (!['cod', 'tempo'].includes(tx.jenis_pembayaran)) continue;
      if (tx.status_pembayaran === 'paid') continue;

      // Validasi RBAC sama seperti per-item
      if (tx.jenis_pembayaran === 'cod') {
        if (req.user.role !== 'admin_cabang') continue;
        const isLastMile = tx.cod_cabang_id && tx.cod_cabang_id.toString() === req.user.cabang_id?.toString();
        const isCabangAsal = tx.jenis_masalah === 'gagal_kirim' &&
            tx.created_by?.cabang_id && tx.created_by.cabang_id.toString() === req.user.cabang_id?.toString();
        if (!isLastMile && !isCabangAsal) continue;
      } else if (tx.jenis_pembayaran === 'tempo') {
        if (req.user.role === 'admin_cabang') {
          if (!tx.created_by?.cabang_id || tx.created_by.cabang_id.toString() !== req.user.cabang_id?.toString()) {
            continue;
          }
        }
      }

      tx.status_pembayaran = 'paid';
      tx.pembayaran_dikonfirmasi_oleh = {
        user_id: req.user._id,
        name: req.user.name,
        role: req.user.role,
        cabang_id: req.user.cabang_id || null,
      };
      tx.pembayaran_dikonfirmasi_pada = now;
      await tx.save();
      updated.push(tx);
    }

    res.json({ message: `${updated.length} transaksi berhasil dikonfirmasi`, count: updated.length, data: updated });
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

// — VERIFIKASI LOKASI (GEOFENCE) —
router.post('/:id/verify-location', auth, rbac('driver', 'admin_cabang', 'super_admin'), async (req, res) => {
  try {
    const { lat, lng, radius_meters } = req.body;
    if (lat == null || lng == null) {
      return res.status(400).json({ message: 'lat dan lng wajib diisi' });
    }

    const tx = await Transaction.findById(req.params.id).lean();
    if (!tx) return res.status(404).json({ message: 'Transaksi tidak ditemukan' });

    const coords = tx.lokasi_penerima?.coordinates;
    if (!coords || coords.length < 2) {
      return res.status(400).json({ message: 'Lokasi penerima tidak tersedia untuk verifikasi' });
    }

    const targetLng = coords[0];
    const targetLat = coords[1];
    const R = 6371000;

    const dLat = (lat - targetLat) * Math.PI / 180;
    const dLng = (lng - targetLng) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(targetLat * Math.PI / 180) * Math.cos(lat * Math.PI / 180) *
              Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const distanceMeters = R * c;

    const defaultRadius = req.user.role === 'driver' ? 150 : 80;
    const maxRadius = radius_meters || defaultRadius;
    const isWithin = distanceMeters <= maxRadius;

    res.json({
      is_within: isWithin,
      distance_meters: Math.round(distanceMeters),
      max_radius: maxRadius,
    });
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