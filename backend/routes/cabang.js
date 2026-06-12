const express = require('express');
const Cabang = require('../models/Cabang');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

router.get('/', auth, async (req, res) => {
  try {
    const cabangs = await Cabang.find().sort({ kode: 1 }).lean();
    res.json({ data: cabangs.map(c => ({ cabang_id: c._id, kode: c.kode, name: c.name, address: c.address, phone: c.phone, kota: c.kota, is_active: c.is_active })) });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { kode, name, address, phone, kota } = req.body;
    const exists = await Cabang.findOne({ kode });
    if (exists) return res.status(400).json({ message: 'Kode cabang sudah terdaftar' });
    const cabang = await Cabang.create({ kode, name, address, phone, kota });
    res.status(201).json(cabang);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.put('/:id', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { kode, name, address, phone, kota, is_active } = req.body;
    const update = {};
    if (kode !== undefined) update.kode = kode;
    if (name !== undefined) update.name = name;
    if (address !== undefined) update.address = address;
    if (phone !== undefined) update.phone = phone;
    if (kota !== undefined) update.kota = kota;
    if (is_active !== undefined) update.is_active = is_active;

    const cabang = await Cabang.findByIdAndUpdate(req.params.id, update, { new: true }).lean();
    if (!cabang) return res.status(404).json({ message: 'Cabang tidak ditemukan' });
    res.json(cabang);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.delete('/:id', auth, rbac('super_admin'), async (req, res) => {
  try {
    const cabang = await Cabang.findByIdAndUpdate(req.params.id, { is_active: false }, { new: true });
    if (!cabang) return res.status(404).json({ message: 'Cabang tidak ditemukan' });
    res.json({ message: 'Cabang dinonaktifkan' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
