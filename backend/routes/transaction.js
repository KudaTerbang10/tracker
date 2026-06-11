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
    const { pengirim, penerima, paket, catatan } = req.body;
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
      pengirim,
      penerima,
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

    const results = [];
    const validIds = [];

    for (const no_resi of no_resi_list) {
      const tx = txMap.get(no_resi);
      if (!tx) {
        results.push({ no_resi, status: 'error', error: 'Transaksi tidak ditemukan' });
        continue;
      }

      if (!canRoleSetStatus(req.user.role, status_baru)) {
        results.push({ no_resi, status: 'error', error: `Role ${req.user.role} tidak memiliki akses untuk status ${status_baru}` });
        continue;
      }

      if (tx.status_saat_ini === status_baru) {
        results.push({ no_resi, status: 'error', error: `Barang ${no_resi} sudah discan sebagai ${status_baru} sebelumnya` });
        continue;
      }

      if (status_baru === 'keluar_cabang') {
        const hasDriver = driver || (nama_driver_manual && nama_driver_manual.trim().length > 0);
        const hasTujuan = (tipe_tujuan === 'penerima') || (tipe_tujuan === 'cabang' && (cabangTujuan || (cabang_nama_manual && cabang_nama_manual.trim().length > 0)));
        if (!hasDriver || !tipe_tujuan || !hasTujuan) {
          results.push({ no_resi, status: 'error', error: 'Driver dan tujuan wajib diisi' });
          continue;
        }
      }

      results.push({ no_resi, status: 'ok' });
      validIds.push(tx._id);
    }

    if (validIds.length > 0) {
      const bulkOps = [];
      for (const txId of validIds) {
        const tx = transactions.find(t => t._id.toString() === txId.toString());
        const log = {
          status: status_baru,
          pelaku: { user_id: req.user._id, name: req.user.name, role: req.user.role },
          lokasi: await getLokasiForUser(req.user),
          timestamp: new Date(),
        };

        const setFields = { status_saat_ini: status_baru, updated_at: new Date() };
        const pushLogs = [log];

        if (status_baru === 'keluar_cabang') {
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
              const dariLokasi = log.lokasi.nama || 'lokasi';
              log.deskripsi = `Paket keluar dari ${dariLokasi} menuju ${cabangName}${driverName ? `, dibawa oleh ${driverName}` : ''}`;

              if (driverName) {
                const autoLog = {
                  status: 'proses_kirim',
                  deskripsi: `Paket dalam perjalanan oleh ${driverName} menuju ${cabangName}`,
                  pelaku: { name: 'Sistem', role: 'system' },
                  tujuan: { tipe: 'cabang', nama: cabangName },
                  timestamp: new Date(Date.now() + 1),
                };
                pushLogs.push(autoLog);
                setFields.status_saat_ini = 'proses_kirim';
              }
            }
          } else if (tipe_tujuan === 'penerima') {
            setFields.tujuan_selanjutnya = { tipe: 'penerima', nama: tx.penerima.name };
            log.tujuan = { tipe: 'penerima', nama: tx.penerima.name };
            const dariLokasi = log.lokasi.nama || 'lokasi';
            log.deskripsi = `Paket keluar dari ${dariLokasi}, diantar langsung ke ${tx.penerima.name}${driverName ? ` oleh ${driverName}` : ''}`;

            if (driverName) {
              const autoLog = {
                status: 'proses_kirim',
                deskripsi: `Paket dalam perjalanan oleh ${driverName} menuju alamat penerima`,
                pelaku: { name: 'Sistem', role: 'system' },
                tujuan: { tipe: 'penerima', nama: tx.penerima.name },
                timestamp: new Date(Date.now() + 1),
              };
              pushLogs.push(autoLog);
              setFields.status_saat_ini = 'proses_kirim';
            }
          }
        } else if (status_baru === 'diterima_cabang') {
          const lokasi = await getLokasiForUser(req.user);
          log.deskripsi = `Paket diterima di ${lokasi.nama}`;
        } else if (status_baru === 'diterima') {
          const namaPenerimaFinal = nama_penerima || tx.penerima.name;
          log.nama_penerima = namaPenerimaFinal;
          log.deskripsi = `Paket telah diterima oleh ${namaPenerimaFinal}${catatan ? ` (${catatan})` : ''}`;
          setFields.nama_penerima_akhir = namaPenerimaFinal;
        }

        bulkOps.push({
          updateOne: {
            filter: { _id: tx._id, status_saat_ini: tx.status_saat_ini },
            update: { $set: setFields, $push: { tracking_logs: { $each: pushLogs } } },
          },
        });
      }

      const bulkResult = await Transaction.bulkWrite(bulkOps, { ordered: false });

      const updatedIds = new Set(
        (await Transaction.find({
          _id: { $in: validIds },
          status_saat_ini: status_baru,
        }, { _id: 1 }).lean()).map(d => d._id.toString())
      );

      for (const r of results) {
        if (r.status === 'ok') {
          const tx = transactions.find(t => t.no_resi === r.no_resi);
          if (tx && !updatedIds.has(tx._id.toString())) {
            r.status = 'error';
            r.error = `Barang ${r.no_resi} sudah discan oleh admin lain`;
          }
        }
      }
    }

    res.json({
      success: results.every(r => r.status === 'ok'),
      total: no_resi_list.length,
      berhasil: results.filter(r => r.status === 'ok').length,
      gagal: results.filter(r => r.status === 'error').length,
      results,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    const { status, search, kode_gerai, page = 1, limit = 20 } = req.query;
    const filter = {};

    if (req.user.role === 'admin_cabang') {
      const cabangId = req.user.cabang_id;
      const tab = req.query.tab || 'current';

      if (tab === 'history') {
        const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);
        filter.createdAt = { $gte: threeDaysAgo };
        filter.$and = [
          { 'tracking_logs.lokasi.cabang_id': new mongoose.Types.ObjectId(cabangId) },
          {
            $expr: {
              $ne: [
                { $arrayElemAt: ['$tracking_logs.lokasi.cabang_id', -1] },
                new mongoose.Types.ObjectId(cabangId),
              ],
            },
          },
        ];
      } else {
        filter.$expr = {
          $eq: [
            { $arrayElemAt: ['$tracking_logs.lokasi.cabang_id', -1] },
            new mongoose.Types.ObjectId(cabangId),
          ],
        };
      }
    } else if (req.user.role === 'driver') {
      const tab = req.query.tab || 'current';
      if (tab === 'history') {
        filter['tracking_logs.driver_ditugaskan.user_id'] = req.user._id;
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
      filter.$or = [
        { no_resi: { $regex: search, $options: 'i' } },
        { barcode_data: { $regex: search, $options: 'i' } },
      ];
    }

    if (kode_gerai) filter.kode_gerai = kode_gerai;

    const total = await Transaction.countDocuments(filter);
    const data = await Transaction.find(filter)
      .sort({ createdAt: -1 })
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
    return cabang ? { nama: cabang.name, tipe: 'cabang', cabang_id: cabang._id } : { nama: '', tipe: '', cabang_id: null };
  }
  return { nama: '', tipe: '', cabang_id: null };
}

module.exports = router;