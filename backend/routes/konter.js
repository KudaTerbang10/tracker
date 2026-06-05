const express = require('express');
const Konter = require('../models/Konter');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

router.get('/', auth, rbac('super_admin'), async (req, res) => {
  try {
    const konters = await Konter.find().lean();
    res.json({ data: konters });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { kode_singkat, name, address, phone } = req.body;
    const konter = new Konter({ kode_singkat: kode_singkat.toUpperCase(), name, address, phone });
    await konter.save();
    res.status(201).json(konter);
  } catch (error) {
    if (error.code === 11000) return res.status(400).json({ message: 'Kode singkat sudah digunakan' });
    res.status(500).json({ message: error.message });
  }
});

router.put('/:id', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { name, address, phone, is_active } = req.body;
    const konter = await Konter.findByIdAndUpdate(req.params.id, { name, address, phone, is_active }, { new: true });
    if (!konter) return res.status(404).json({ message: 'Konter tidak ditemukan' });
    res.json(konter);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
