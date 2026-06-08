const express = require('express');
const mongoose = require('mongoose');
const Transaction = require('../models/Transaction');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');
const generateResi = require('../utils/resiGenerator');
const { canRoleSetStatus } = require('../utils/statusValidator');

const router = express.Router();

router.post('/', auth, rbac('admin_konter', 'staff_gudang', 'admin_cabang'), async (req, res) => {
  try {
    const { pengirim, penerima, paket, catatan } = req.body;
    if (!pengirim || !penerima || !paket) {
      return res.status(400).json({ message: 'Data pengirim, penerima, dan paket wajib diisi' });
    }

    let kodeGerai;
    let createdBy;
    let lokasi;

    if (req.user.role === 'admin_cabang') {
      const Cabang = require('../models/Cabang');
      const cabang = await Cabang.findById(req.user.cabang_id);
      if (!cabang) return res.status(400).json({ message: 'Cabang tidak ditemukan' });
      kodeGerai = cabang.kode;
      createdBy = {
        user_id: req.user._id,
        name: req.user.name,
        role: 'admin_cabang',
        konter_id: null,
        konter_name: '',
        gudang_id: null,
        gudang_name: '',
        cabang_id: req.user.cabang_id,
        cabang_name: cabang.name,
      };
      lokasi = { nama: cabang.name, tipe: 'cabang', cabang_id: req.user.cabang_id };
    } else if (req.user.role === 'staff_gudang') {
      const gudang = await (require('../models/Gudang')).findById(req.user.gudang_id);
      if (!gudang) return res.status(400).json({ message: 'Gudang tidak ditemukan' });
      kodeGerai = gudang.kode;
      createdBy = {
        user_id: req.user._id,
        name: req.user.name,
        role: 'staff_gudang',
        konter_id: null,
        konter_name: '',
        gudang_id: req.user.gudang_id,
        gudang_name: gudang.name,
      };
      lokasi = { nama: gudang.name, tipe: 'gudang' };
    } else {
      const konter = await (require('../models/Konter')).findById(req.user.konter_id);
      if (!konter) return res.status(400).json({ message: 'Konter tidak ditemukan' });
      kodeGerai = konter.kode_singkat;
      createdBy = {
        user_id: req.user._id,
        name: req.user.name,
        role: 'admin_konter',
        konter_id: req.user.konter_id,
        konter_name: konter.name,
        gudang_id: null,
        gudang_name: '',
      };
      lokasi = { nama: konter.name, tipe: 'konter' };
    }

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
      status_saat_ini: (req.user.role === 'staff_gudang' && req.user.gudang_id) ? 'diterima_gudang' : 'diterima_konter',
      tracking_logs: [{
        status: (req.user.role === 'staff_gudang' && req.user.gudang_id) ? 'diterima_gudang' : 'diterima_konter',
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
    const { no_resi_list, status_baru, driver_user_id, tipe_tujuan, gudang_tujuan_id, nama_driver_manual, gudang_nama_manual, catatan, nama_penerima } = req.body;
    if (!no_resi_list || !no_resi_list.length || !status_baru) {
      return res.status(400).json({ message: 'no_resi_list dan status_baru wajib diisi' });
    }

    const transactions = await Transaction.find({ no_resi: { $in: no_resi_list } }).lean();
    const txMap = new Map(transactions.map(tx => [tx.no_resi, tx]));

    let driver = null;
    let gudangTujuan = null;

    if ((status_baru === 'keluar_gudang' || status_baru === 'keluar_konter') && driver_user_id) {
      driver = await (require('../models/User')).findById(driver_user_id).lean();
      if (!driver) return res.status(400).json({ message: 'Driver tidak ditemukan' });
    }
    if ((status_baru === 'keluar_gudang' || status_baru === 'keluar_konter') && tipe_tujuan === 'gudang' && gudang_tujuan_id) {
      gudangTujuan = await (require('../models/Gudang')).findById(gudang_tujuan_id).lean();
      if (!gudangTujuan) {
        gudangTujuan = await (require('../models/Cabang')).findById(gudang_tujuan_id).lean();
      }
      if (!gudangTujuan) return res.status(400).json({ message: 'Cabang tujuan tidak ditemukan' });
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

      if (status_baru === 'keluar_gudang' || status_baru === 'keluar_konter') {
        const hasDriver = driver || (nama_driver_manual && nama_driver_manual.trim().length > 0);
        const hasTujuan = (tipe_tujuan === 'penerima') || (tipe_tujuan === 'gudang' && (gudangTujuan || (gudang_nama_manual && gudang_nama_manual.trim().length > 0)));
        if (!hasDriver || !tipe_tujuan || !hasTujuan) {
          results.push({ no_resi, status: 'error', error: 'Driver dan tujuan wajib diisi' });
          continue;
        }
        if (status_baru === 'keluar_gudang' && tipe_tujuan === 'gudang' && req.user.role === 'staff_gudang' && gudangTujuan && req.user.gudang_id && gudangTujuan._id.toString() === req.user.gudang_id.toString()) {
          results.push({ no_resi, status: 'error', error: 'Tidak dapat mengirim ke gudang sendiri' });
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

        if (status_baru === 'keluar_gudang' || status_baru === 'keluar_konter') {
          const driverName = driver ? driver.name : (nama_driver_manual || '');
          const driverPhone = driver ? driver.phone : '';
          const driverId = driver ? driver._id : null;

          if (driverName) {
            setFields.nama_driver = driverName;
            setFields.kontak_driver = driverPhone || null;
            setFields.driver_user_id = driverId;
            log.driver_ditugaskan = { user_id: driverId, nama: driverName, kontak: driverPhone || '' };
          }

          if (tipe_tujuan === 'gudang') {
            const gudangName = gudangTujuan ? gudangTujuan.name : (gudang_nama_manual || '');
            if (gudangName) {
              setFields.tujuan_selanjutnya = { tipe: 'gudang', gudang_id: gudangTujuan ? gudangTujuan._id : null, nama: gudangName };
              log.tujuan = { tipe: 'gudang', nama: gudangName };
              const dariLokasi = log.lokasi.nama || 'lokasi';
              log.deskripsi = `Paket keluar dari ${dariLokasi} menuju ${gudangName}${driverName ? `, dibawa oleh ${driverName}` : ''}`;
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
                timestamp: new Date(Date.now() + 1),
              };
              pushLogs.push(autoLog);
              setFields.status_saat_ini = 'proses_kirim';
            }
          }
        } else if (status_baru === 'diterima_gudang') {
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

      await Transaction.bulkWrite(bulkOps, { ordered: false });
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
    const { status, kode_gerai, page = 1, limit = 20 } = req.query;
    const filter = {};

    if (req.user.role === 'admin_konter') {
      filter['created_by.konter_id'] = req.user.konter_id;
      const allowed = ['diterima_konter', 'keluar_konter'];
      filter.status_saat_ini = (status && allowed.includes(status)) ? status : { $in: allowed };
    } else if (req.user.role === 'admin_cabang') {
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
    } else if (req.user.role === 'staff_gudang') {
      const gudangId = req.user.gudang_id;
      const allowedGudang = ['diterima_gudang', 'keluar_gudang'];
      const statusFilter = (status && allowedGudang.includes(status)) ? status : { $in: allowedGudang };
      filter.$or = [
        {
          status_saat_ini: statusFilter,
          $expr: {
            $eq: [
              { $arrayElemAt: ['$tracking_logs.lokasi.gudang_id', -1] },
              new mongoose.Types.ObjectId(gudangId),
            ],
          },
        },
        { 'created_by.user_id': req.user._id },
      ];
    } else if (req.user.role === 'driver') {
      filter.driver_user_id = req.user._id;
      if (status) filter.status_saat_ini = status;
    } else {
      if (status) filter.status_saat_ini = status;
    }

    if (kode_gerai) filter.kode_gerai = kode_gerai;

    const total = await Transaction.countDocuments(filter);
    const data = await Transaction.find(filter)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .lean();

    const needBackfill = data.some(t => t.admin_konter?.konter_id && !t.admin_konter?.konter_name);
    if (needBackfill) {
      const Konter = require('../models/Konter');
      const ids = [...new Set(data.filter(t => t.admin_konter?.konter_id && !t.admin_konter?.konter_name).map(t => t.admin_konter.konter_id.toString()))];
      const konters = await Konter.find({ _id: { $in: ids } }, { name: 1 }).lean();
      const map = new Map(konters.map(k => [k._id.toString(), k.name]));
      for (const tx of data) {
        if (tx.admin_konter?.konter_id && !tx.admin_konter?.konter_name) {
          tx.admin_konter.konter_name = map.get(tx.admin_konter.konter_id.toString()) || '';
        }
      }
    }

    // Map old admin_konter to created_by for backward compatibility
    for (const tx of data) {
      if (tx.admin_konter && !tx.created_by) {
        tx.created_by = {
          user_id: tx.admin_konter.user_id,
          name: tx.admin_konter.name,
        role: 'admin_konter',
        konter_id: tx.admin_konter.konter_id,
        konter_name: tx.admin_konter.konter_name || '',
        gudang_id: null,
        gudang_name: '',
        cabang_id: null,
        cabang_name: '',
        };
      }
      delete tx.admin_konter;
    }

    res.json({ data, total, page: parseInt(page), totalPages: Math.ceil(total / limit) });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.delete('/:id', auth, rbac('admin_konter', 'staff_gudang', 'admin_cabang'), async (req, res) => {
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
    return cabang ? { nama: cabang.name, tipe: 'cabang', cabang_id: cabang._id, konter_id: null, gudang_id: null } : { nama: '', tipe: '', cabang_id: null, konter_id: null, gudang_id: null };
  }
  if (user.konter_id) {
    const konter = await (require('../models/Konter')).findById(user.konter_id).lean();
    return konter ? { nama: konter.name, tipe: 'konter', konter_id: konter._id, gudang_id: null } : { nama: '', tipe: '', konter_id: null, gudang_id: null };
  }
  if (user.gudang_id) {
    const gudang = await (require('../models/Gudang')).findById(user.gudang_id).lean();
    return gudang ? { nama: gudang.name, tipe: 'gudang', konter_id: null, gudang_id: gudang._id } : { nama: '', tipe: '', konter_id: null, gudang_id: null };
  }
  return { nama: '', tipe: '', konter_id: null, gudang_id: null };
}

module.exports = router;
