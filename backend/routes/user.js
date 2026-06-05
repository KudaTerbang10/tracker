const express = require('express');
const User = require('../models/User');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

router.get('/', auth, rbac('super_admin'), async (req, res) => {
  try {
    const users = await User.find().lean();
    const data = users.map(u => {
      const { password, ...rest } = u;
      return rest;
    });
    res.json({ data });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { name, email, password, phone, role, konter_id, gudang_id } = req.body;
    const exists = await User.findOne({ email });
    if (exists) return res.status(400).json({ message: 'Email sudah terdaftar' });

    const user = new User({ name, email, password, phone, role, konter_id, gudang_id });
    await user.save();
    res.status(201).json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.put('/:id', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { name, email, phone, role, konter_id, gudang_id, is_active } = req.body;
    const update = {};
    if (name !== undefined) update.name = name;
    if (email !== undefined) update.email = email;
    if (phone !== undefined) update.phone = phone;
    if (role !== undefined) update.role = role;
    if (konter_id !== undefined) update.konter_id = konter_id;
    if (gudang_id !== undefined) update.gudang_id = gudang_id;
    if (is_active !== undefined) update.is_active = is_active;

    const user = await User.findByIdAndUpdate(req.params.id, update, { new: true }).lean();
    if (!user) return res.status(404).json({ message: 'User tidak ditemukan' });
    const { password, ...rest } = user;
    res.json(rest);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.delete('/:id', auth, rbac('super_admin'), async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(req.params.id, { is_active: false }, { new: true });
    if (!user) return res.status(404).json({ message: 'User tidak ditemukan' });
    res.json({ message: 'User dinonaktifkan' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
