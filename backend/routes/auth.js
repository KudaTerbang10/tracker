const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Konter = require('../models/Konter');
const Gudang = require('../models/Gudang');
const Cabang = require('../models/Cabang');
const auth = require('../middleware/auth');

const router = express.Router();

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email dan password wajib diisi' });
    }

    const user = await User.findOne({ email, is_active: true });
    if (!user) {
      return res.status(401).json({ message: 'Email atau password salah' });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Email atau password salah' });
    }

    let lokasi = null;
    if (user.cabang_id) {
      lokasi = await Cabang.findById(user.cabang_id).lean();
    } else if (user.konter_id) {
      lokasi = await Konter.findById(user.konter_id).lean();
    } else if (user.gudang_id) {
      lokasi = await Gudang.findById(user.gudang_id).lean();
    }

    const token = jwt.sign(
      { id: user._id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        konter_id: user.konter_id,
        gudang_id: user.gudang_id,
        cabang_id: user.cabang_id,
        lokasi,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/me', auth, async (req, res) => {
  let lokasi = null;
  if (req.user.cabang_id) {
    lokasi = await Cabang.findById(req.user.cabang_id).lean();
  } else if (req.user.konter_id) {
    lokasi = await Konter.findById(req.user.konter_id).lean();
  } else if (req.user.gudang_id) {
    lokasi = await Gudang.findById(req.user.gudang_id).lean();
  }
  res.json({ ...req.user.toJSON(), lokasi });
});

module.exports = router;
