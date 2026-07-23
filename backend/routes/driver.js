const express = require('express');
const User = require('../models/User');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

router.get('/', auth, async (req, res) => {
  try {
    const { q, cabang_id } = req.query;
    const filter = { role: 'driver', is_active: true };

    if (cabang_id) {
      filter.cabang_id = cabang_id;
    }

    if (q) {
      // Anchored prefix agar bisa pakai index { role: 1, is_active: 1, name: 1 }
      filter.name = { $regex: '^' + q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };
    }

    const drivers = await User.find(filter, { name: 1, phone: 1, email: 1, role: 1, _id: 1 }).lean();
    res.json({ data: drivers.map(d => ({ user_id: d._id, name: d.name, phone: d.phone, email: d.email })) });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/test-logins', async (req, res) => {
  try {
    const drivers = await User.find({ role: 'driver', is_active: true }, { name: 1, email: 1, _id: 0 })
      .limit(2)
      .lean();
    res.json({ data: drivers });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
