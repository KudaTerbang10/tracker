const express = require('express');
const User = require('../models/User');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

router.get('/', auth, async (req, res) => {
  try {
    const { q } = req.query;
    const filter = { role: 'driver', is_active: true };

    if (q) {
      filter.$or = [
        { name: { $regex: q, $options: 'i' } },
        { phone: { $regex: q, $options: 'i' } },
      ];
    }

    const drivers = await User.find(filter, { name: 1, phone: 1, email: 1, role: 1, _id: 1 }).lean();
    res.json({ data: drivers.map(d => ({ user_id: d._id, name: d.name, phone: d.phone, email: d.email })) });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
