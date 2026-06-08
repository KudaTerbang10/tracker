const express = require('express');
const Cabang = require('../models/Cabang');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

router.get('/', auth, async (req, res) => {
  try {
    const filter = { is_active: true };
    const cabangs = await Cabang.find(filter).sort({ name: 1 }).lean();
    res.json({ data: cabangs.map(c => ({ cabang_id: c._id, kode: c.kode, name: c.name, address: c.address })) });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
