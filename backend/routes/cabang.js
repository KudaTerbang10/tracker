const express = require('express');
const Cabang = require('../models/Cabang');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

const publicRateLimitMap = new Map();
const PUBLIC_WINDOW = 300_000;
const PUBLIC_MAX = 1;

function getPublicRateLimit(ip) {
  const now = Date.now();
  let entry = publicRateLimitMap.get(ip);
  if (!entry || now - entry.windowStart > PUBLIC_WINDOW) {
    entry = { windowStart: now, count: 0 };
    publicRateLimitMap.set(ip, entry);
  }
  return entry;
}

setInterval(() => {
  const now = Date.now();
  for (const [ip, entry] of publicRateLimitMap) {
    if (now - entry.windowStart > PUBLIC_WINDOW) {
      publicRateLimitMap.delete(ip);
    }
  }
}, 300_000).unref();

router.get('/', async (req, res) => {
  try {
    const ip = req.ip || req.connection?.remoteAddress || 'unknown';

    if (!req.headers.authorization) {
      const rate = getPublicRateLimit(ip);
      rate.count++;

      if (rate.count > PUBLIC_MAX) {
        return res.status(429).json({
          message: 'Terlalu banyak permintaan.',
          retry_after_seconds: Math.ceil((rate.windowStart + PUBLIC_WINDOW - Date.now()) / 1000),
        });
      }
    }

    const isAuth = !!req.headers.authorization;
    const filter = isAuth ? {} : { is_active: true };
    const cabangs = await Cabang.find(filter).sort({ kode: 1 }).lean();
    res.json({ data: cabangs.map(c => {
      const [lng, lat] = c.lokasi?.coordinates ?? [];
      return { cabang_id: c._id, kode: c.kode, name: c.name, address: c.address, phone: c.phone, kota: c.kota, is_active: c.is_active, latitude: lat ?? null, longitude: lng ?? null };
    }) });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { kode, name, address, phone, kota, latitude, longitude } = req.body;
    const exists = await Cabang.findOne({ kode });
    if (exists) return res.status(400).json({ message: 'Kode cabang sudah terdaftar' });
    const lokasi = (latitude != null && longitude != null) ? { type: 'Point', coordinates: [longitude, latitude] } : undefined;
    const cabang = await Cabang.create({ kode, name, address, phone, kota, ...(lokasi ? { lokasi } : {}) });
    res.status(201).json(cabang);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.put('/:id', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { kode, name, address, phone, kota, latitude, longitude, is_active } = req.body;
    const update = {};
    if (kode !== undefined) update.kode = kode;
    if (name !== undefined) update.name = name;
    if (address !== undefined) update.address = address;
    if (phone !== undefined) update.phone = phone;
    if (kota !== undefined) update.kota = kota;
    if (latitude !== undefined && longitude !== undefined) {
      update.lokasi = { type: 'Point', coordinates: [longitude, latitude] };
    }
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

router.get('/kota', auth, async (req, res) => {
  try {
    const cities = await Cabang.distinct('kota', { is_active: true, kota: { $ne: '' } });
    cities.sort();
    res.json({ data: cities });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
