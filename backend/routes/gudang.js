const express = require('express');
const Gudang = require('../models/Gudang');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

router.get('/', auth, async (req, res) => {
  try {
    const { q } = req.query;
    const filter = { is_active: true };

    if (q) {
      filter.$or = [
        { name: { $regex: q, $options: 'i' } },
        { kode: { $regex: q, $options: 'i' } },
      ];
    }

    const gudangs = await Gudang.find(filter).lean();
    res.json({ data: gudangs.map(g => ({ gudang_id: g._id, kode: g.kode, name: g.name, address: g.address })) });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
