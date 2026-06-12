const express = require('express');
const User = require('../models/User');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

router.get('/', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { search } = req.query;
    const filter = {};
    if (search) {
      filter.$or = [
        { name: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } },
      ];
    }
    const users = await User.find(filter).lean();
    res.json({ data: users });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { name, email, password, phone, role, cabang_id } = req.body;
    const exists = await User.findOne({ email });
    if (exists) return res.status(400).json({ message: 'Email sudah terdaftar' });

    const user = new User({ name, email, password, phone, role, cabang_id });
    await user.save();
    res.status(201).json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.put('/:id', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { name, email, phone, role, cabang_id, is_active, password: newPassword } = req.body;
    const update = {};
    if (name !== undefined) update.name = name;
    if (email !== undefined) update.email = email;
    if (phone !== undefined) update.phone = phone;
    if (role !== undefined) update.role = role;
    if (cabang_id !== undefined) update.cabang_id = cabang_id;
    if (is_active !== undefined) update.is_active = is_active;
    if (newPassword !== undefined && newPassword.length > 0) update.password = newPassword;

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
