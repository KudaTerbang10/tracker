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
      { $sort: { total: -1 } },
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

module.exports = router;
