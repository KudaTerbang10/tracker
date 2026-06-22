const express = require('express');
const mongoose = require('mongoose');
const Manifest = require('../models/Manifest');
const Transaction = require('../models/Transaction');
const auth = require('../middleware/auth');
const { canRoleSetStatus } = require('../utils/statusValidator');

const router = express.Router();

// GET /api/manifests — list manifests
// Admin_cabang: lihat manifest yang dibuat di cabangnya
// Driver: lihat manifest yang ditugaskan ke dirinya
// Super_admin: lihat semua
router.get('/', auth, async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const filter = {};

    if (req.user.role === 'admin_cabang') {
      filter.asal_cabang_id = new mongoose.Types.ObjectId(req.user.cabang_id);
    } else if (req.user.role === 'driver') {
      filter['driver.user_id'] = req.user._id;
    }

    if (status) {
      // Support comma-separated: "dibuat,dalam_perjalanan"
      const statusList = status.split(',').map(s => s.trim()).filter(Boolean);
      if (statusList.length === 1) {
        filter.status = statusList[0];
      } else if (statusList.length > 1) {
        filter.status = { $in: statusList };
      }
    }

    const total = await Manifest.countDocuments(filter);
    const data = await Manifest.find(filter)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .lean();

    res.json({
      data,
      total,
      page: parseInt(page),
      totalPages: Math.ceil(total / limit),
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// GET /api/manifests/stats/summary — aggregate work unit per status
router.get('/stats/summary', auth, async (req, res) => {
  try {
    const match = {};
    if (req.user.role === 'driver') {
      match['driver.user_id'] = req.user._id;
    } else if (req.user.role === 'admin_cabang') {
      match.asal_cabang_id = new mongoose.Types.ObjectId(req.user.cabang_id);
    }

    const stats = await Manifest.aggregate([
      { $match: match },
      {
        $group: {
          _id: '$status',
          total_work_unit: { $sum: '$work_unit' },
          total_manifest: { $sum: 1 },
          total_resi: { $sum: '$total_resi' },
        },
      },
    ]);

    // Hitung grand total
    let grandWorkUnit = 0;
    let grandManifest = 0;
    let grandResi = 0;
    for (const s of stats) {
      grandWorkUnit += s.total_work_unit;
      grandManifest += s.total_manifest;
      grandResi += s.total_resi;
    }

    res.json({
      data: stats,
      total: {
        work_unit: grandWorkUnit,
        manifest: grandManifest,
        resi: grandResi,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// GET /api/manifests/:id — detail manifest + transaksi di dalamnya
router.get('/:id', auth, async (req, res) => {
  try {
    const manifest = await Manifest.findById(req.params.id).lean();
    if (!manifest) {
      return res.status(404).json({ message: 'Manifest tidak ditemukan' });
    }

    // Ambil semua transaksi dalam manifest ini
    let transactions;
    if (manifest.status === 'selesai') {
      // Manifest selesai — cari hanya via no_manifest field
      // agar transaksi yang sudah dipindah ke manifest baru tidak ikut
      transactions = await Transaction.find({
        no_manifest: manifest.no_manifest,
      })
        .sort({ createdAt: 1 })
        .lean();
    } else {
      // Manifest aktif — cari dari no_manifest DAN tracking_logs
      transactions = await Transaction.find({
        $or: [
          { no_manifest: manifest.no_manifest },
          { 'tracking_logs.no_manifest': manifest.no_manifest },
        ],
      })
        .sort({ createdAt: 1 })
        .lean();
    }

    // Hitung progress
    const total = transactions.length;
    let selesai;
    if (manifest.status === 'selesai') {
      // Manifest sudah selesai — jangan hitung dari status transaksi saat ini
      // karena transaksi bisa berubah status lagi di manifest berikutnya
      selesai = total;
    } else {
      selesai = transactions.filter(
        tx => tx.status_saat_ini === 'diterima' ||
              tx.status_saat_ini === 'diterima_cabang',
      ).length;
    }

    // Update status manifest berdasarkan progress
    if (selesai === total && total > 0 && manifest.status !== 'selesai') {
      await Manifest.findByIdAndUpdate(req.params.id, {
        status: 'selesai',
        completed_at: new Date(),
      });
      manifest.status = 'selesai';
      manifest.completed_at = new Date();
    } else if (selesai > 0 && selesai < total && manifest.status === 'dibuat') {
      await Manifest.findByIdAndUpdate(req.params.id, {
        status: 'dalam_perjalanan',
      });
      manifest.status = 'dalam_perjalanan';
    } else if (total > 0 && manifest.status === 'dibuat') {
      // Ada transaksi, sudah dikirim tapi belum ada yang selesai
      await Manifest.findByIdAndUpdate(req.params.id, {
        status: 'dalam_perjalanan',
      });
      manifest.status = 'dalam_perjalanan';
    }

    // Hitung total koli & berat dari transaksi
    const totalKoli = transactions.reduce((sum, tx) => sum + (tx.paket?.jumlah_koli || 0), 0);
    const totalBerat = transactions.reduce((sum, tx) => sum + (tx.paket?.berat_kg || 0), 0);

    res.json({
      ...manifest,
      transactions,
      jumlah_koli: totalKoli,
      total_berat: totalBerat,
      progress: { total, selesai },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// POST /api/manifests/:id/receive — batch receive semua resi dalam manifest (scan datang)
router.post('/:id/receive', auth, async (req, res) => {
  try {
    if (!canRoleSetStatus(req.user.role, 'diterima_cabang')) {
      return res.status(403).json({
        message: `Role ${req.user.role} tidak memiliki akses`,
      });
    }

    const manifest = await Manifest.findById(req.params.id).lean();
    if (!manifest) {
      return res.status(404).json({ message: 'Manifest tidak ditemukan' });
    }

    // Cari semua transaksi dalam manifest yang masih bisa diterima
    const transactions = await Transaction.find({
      no_manifest: manifest.no_manifest,
      status_saat_ini: { $in: ['keluar_cabang', 'proses_kirim'] },
    }).lean();

    if (transactions.length === 0) {
      return res.json({
        success: true,
        message: 'Tidak ada transaksi yang perlu diterima',
        berhasil: 0,
      });
    }

    const ids = transactions.map(tx => tx._id);
    const now = new Date();
    const Cabang = require('../models/Cabang');
    const cabang = req.user.cabang_id
      ? await Cabang.findById(req.user.cabang_id).lean()
      : null;
    const userLokasi = {
      nama: cabang?.name || '',
      tipe: 'cabang',
      cabang_id: req.user.cabang_id || null,
    };

    const bulkOps = transactions.map(tx => ({
      updateOne: {
        filter: { _id: tx._id, status_saat_ini: tx.status_saat_ini },
        update: {
          $set: {
            status_saat_ini: 'diterima_cabang',
            current_cabang_id: req.user.cabang_id || null,
            updatedAt: now,
            updated_at: now,
          },
          $push: {
            tracking_logs: {
              status: 'diterima_cabang',
              deskripsi: `Paket diterima di ${userLokasi.nama || 'cabang tujuan'}`,
              pelaku: {
                user_id: req.user._id,
                name: req.user.name,
                role: req.user.role,
              },
              lokasi: userLokasi,
              timestamp: now,
            },
          },
        },
      },
    }));

    await Transaction.bulkWrite(bulkOps, { ordered: false });

    // Cek apakah manifest sudah selesai semua
    const sisa = await Transaction.countDocuments({
      no_manifest: manifest.no_manifest,
      status_saat_ini: { $in: ['keluar_cabang', 'proses_kirim'] },
    });

    if (sisa === 0) {
      await Manifest.findByIdAndUpdate(req.params.id, {
        status: 'selesai',
        completed_at: now,
      });
    } else {
      await Manifest.findByIdAndUpdate(req.params.id, {
        status: 'dalam_perjalanan',
      });
    }

    res.json({
      success: true,
      berhasil: transactions.length,
      message: `${transactions.length} transaksi diterima di cabang`,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// POST /api/manifests/receive-by-number — scan datang via nomor manifest
router.post('/receive-by-number', auth, async (req, res) => {
  try {
    const { no_manifest } = req.body;
    if (!no_manifest) {
      return res.status(400).json({ message: 'no_manifest wajib diisi' });
    }

    const manifest = await Manifest.findOne({ no_manifest }).lean();
    if (!manifest) {
      return res.status(404).json({ message: 'Manifest tidak ditemukan' });
    }

    // Forward ke handler receive yang sudah ada
    req.params.id = manifest._id.toString();
    // Redirect secara internal — copy logic dari POST /:id/receive
    const { canRoleSetStatus } = require('../utils/statusValidator');
    if (!canRoleSetStatus(req.user.role, 'diterima_cabang')) {
      return res.status(403).json({
        message: `Role ${req.user.role} tidak memiliki akses`,
      });
    }

    const transactions = await Transaction.find({
      no_manifest,
      status_saat_ini: { $in: ['keluar_cabang', 'proses_kirim'] },
    }).lean();

    if (transactions.length === 0) {
      return res.json({
        success: true,
        message: 'Tidak ada transaksi yang perlu diterima',
        berhasil: 0,
      });
    }

    const ids = transactions.map(tx => tx._id);
    const now = new Date();
    const Cabang = require('../models/Cabang');
    const cabang = req.user.cabang_id
      ? await Cabang.findById(req.user.cabang_id).lean()
      : null;
    const userLokasi = {
      nama: cabang?.name || '',
      tipe: 'cabang',
      cabang_id: req.user.cabang_id || null,
    };

    const bulkOps = transactions.map(tx => ({
      updateOne: {
        filter: { _id: tx._id, status_saat_ini: tx.status_saat_ini },
        update: {
          $set: {
            status_saat_ini: 'diterima_cabang',
            current_cabang_id: req.user.cabang_id || null,
            updatedAt: now,
            updated_at: now,
          },
          $push: {
            tracking_logs: {
              status: 'diterima_cabang',
              deskripsi: `Paket diterima di ${userLokasi.nama || 'cabang tujuan'}`,
              pelaku: {
                user_id: req.user._id,
                name: req.user.name,
                role: req.user.role,
              },
              lokasi: userLokasi,
              timestamp: now,
            },
          },
        },
      },
    }));

    await Transaction.bulkWrite(bulkOps, { ordered: false });

    const sisa = await Transaction.countDocuments({
      no_manifest,
      status_saat_ini: { $in: ['keluar_cabang', 'proses_kirim'] },
    });

    if (sisa === 0) {
      await Manifest.findByIdAndUpdate(manifest._id, {
        status: 'selesai',
        completed_at: now,
      });
    } else {
      await Manifest.findByIdAndUpdate(manifest._id, {
        status: 'dalam_perjalanan',
      });
    }

    res.json({
      success: true,
      no_manifest,
      berhasil: transactions.length,
      message: `${transactions.length} transaksi diterima di cabang`,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
