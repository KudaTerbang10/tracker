const express = require('express');
const Transaction = require('../models/Transaction');
const User = require('../models/User');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

router.get('/traffic', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { start, end } = req.query;
    const match = {};
    if (start || end) {
      match.createdAt = {};
      if (start) match.createdAt.$gte = new Date(start);
      if (end) match.createdAt.$lte = new Date(end);
    }

    const traffic = await Transaction.aggregate([
      { $match: match },
      { $group: { _id: '$kode_gerai', total: { $sum: 1 } } },
      { $sort: { antar_cabang: -1, total: -1 } },
      { $limit: 10 },
    ]);

    res.json({ data: traffic.map(t => ({ kode_gerai: t._id, total: t.total })) });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/customers-top', auth, rbac('super_admin'), async (req, res) => {
  try {
    const topCustomers = await Transaction.aggregate([
      { $group: { _id: { name: '$pengirim.name', phone: '$pengirim.phone' }, total: { $sum: 1 }, total_biaya: { $sum: '$paket.biaya_kirim' } } },
      { $sort: { total: -1 } },
      { $limit: 10 },
      { $project: { _id: 0, name: '$_id.name', phone: '$_id.phone', total: 1, total_biaya: 1 } },
    ]);

    res.json({ data: topCustomers });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/summary', auth, rbac('super_admin'), async (req, res) => {
  try {
    const [totalTransaksi, statusCount, totalDriver] = await Promise.all([
      Transaction.countDocuments(),
      Transaction.aggregate([{ $group: { _id: '$status_saat_ini', count: { $sum: 1 } } }, { $sort: { _id: 1 } }]),
      User.countDocuments({ role: 'driver', is_active: true }),
    ]);

    res.json({ total_transaksi: totalTransaksi, status_distribution: statusCount, total_driver: totalDriver });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/per-cabang', auth, rbac('super_admin'), async (req, res) => {
  try {
    const month = parseInt(req.query.month);
    const year = parseInt(req.query.year);
    if (!month || !year || month < 1 || month > 12)
      return res.status(400).json({ message: 'month (1-12) and year required' });

    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59, 999);

    const data = await Transaction.aggregate([
      { $match: { createdAt: { $gte: startDate, $lte: endDate } } },
      { $group: { _id: '$kode_gerai', total_resi: { $sum: 1 }, total_biaya: { $sum: '$paket.biaya_kirim' } } },
      { $lookup: { from: 'cabangs', localField: '_id', foreignField: 'kode', as: 'cabang' } },
      { $addFields: { cabang_name: { $ifNull: [{ $arrayElemAt: ['$cabang.name', 0] }, '$_id'] } } },
      { $project: { _id: 0, kode_gerai: '$_id', cabang_name: 1, total_resi: 1, total_biaya: 1 } },
      { $sort: { total_resi: -1 } },
    ]);

    res.json({ data, month, year });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/drivers', auth, rbac('super_admin'), async (req, res) => {
  try {
    const month = parseInt(req.query.month);
    const year = parseInt(req.query.year);
    if (!month || !year || month < 1 || month > 12)
      return res.status(400).json({ message: 'month (1-12) and year required' });

    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59, 999);

    const data = await Transaction.aggregate([
      { $match: { createdAt: { $gte: startDate, $lte: endDate } } },
      { $unwind: '$tracking_logs' },
      {
        $match: {
          'tracking_logs.status': 'keluar_cabang',
          'tracking_logs.driver_ditugaskan': { $exists: true, $ne: null },
        },
      },
      {
        $group: {
          _id: '$tracking_logs.driver_ditugaskan.user_id',
          driver_name: { $first: '$tracking_logs.driver_ditugaskan.nama' },
          driver_kontak: { $first: '$tracking_logs.driver_ditugaskan.kontak' },
          total: { $sum: 1 },
          antar_cabang: {
            $sum: {
              $cond: [{ $eq: ['$tracking_logs.tujuan.tipe', 'cabang'] }, 1, 0],
            },
          },
          antar_penerima: {
            $sum: {
              $cond: [{ $eq: ['$tracking_logs.tujuan.tipe', 'penerima'] }, 1, 0],
            },
          },
        },
      },
      {
        $project: {
          _id: 1,
          driver_id: '$_id',
          driver_name: 1,
          driver_kontak: 1,
          total: 1,
          antar_cabang: 1,
          antar_penerima: 1,
        },
      },
      { $sort: { total: -1 } },
    ]);

    res.json({ data, month, year });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
