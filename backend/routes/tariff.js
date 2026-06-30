const express = require('express');
const Tariff = require('../models/Tariff');
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

router.get('/public', async (req, res) => {
  try {
    const ip = req.ip || req.connection?.remoteAddress || 'unknown';
    const rate = getPublicRateLimit(ip);
    rate.count++;

    if (rate.count > PUBLIC_MAX) {
      return res.status(429).json({
        message: 'Terlalu banyak permintaan.',
        retry_after_seconds: Math.ceil((rate.windowStart + PUBLIC_WINDOW - Date.now()) / 1000),
      });
    }

    const tariffs = await Tariff.find({}).sort({ asal: 1, tujuan: 1 }).lean();
    res.json({
      tariffs: tariffs.map(t => ({
        key: t.key,
        asal: t.asal,
        tujuan: t.tujuan,
        min: t.min,
        perkg: t.perkg,
        est: t.est,
      })),
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    const { asal, tujuan, page = 1, limit = 20 } = req.query;
    let filter = {};
    if (asal) filter.asal = { $regex: '^' + asal.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };
    if (tujuan) filter.tujuan = { $regex: '^' + tujuan.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };

    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.max(1, Math.min(2000, parseInt(limit)));
    const skip = (pageNum - 1) * limitNum;

    const [tariffs, total] = await Promise.all([
      Tariff.find(filter).sort({ asal: 1, tujuan: 1 }).skip(skip).limit(limitNum).lean(),
      Tariff.countDocuments(filter),
    ]);

    res.json({
      data: tariffs.map(t => ({ tariff_id: t._id, key: t.key, asal: t.asal, tujuan: t.tujuan, min: t.min, perkg: t.perkg, est: t.est })),
      total,
      page: pageNum,
      totalPages: Math.ceil(total / limitNum),
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { asal, tujuan, min, perkg, est } = req.body;
    if (!asal || !tujuan || min === undefined || perkg === undefined || !est) {
      return res.status(400).json({ message: 'Semua field wajib diisi' });
    }

    const asalNorm = asal.toLowerCase().trim();
    const tujuanNorm = tujuan.toLowerCase().trim();
    const key = `${asalNorm}|${tujuanNorm}`;

    // Cek duplikat via key dan juga via asal+tujuan langsung
    const exists = await Tariff.findOne({
      $or: [
        { key },
        { asal: asalNorm, tujuan: tujuanNorm },
      ],
    });
    if (exists) return res.status(409).json({ message: 'Rute sudah terdaftar' });

    const tariff = await Tariff.create({ key, asal: asalNorm, tujuan: tujuanNorm, min, perkg, est });
    res.status(201).json({ tariff_id: tariff._id, key: tariff.key, asal: tariff.asal, tujuan: tariff.tujuan, min: tariff.min, perkg: tariff.perkg, est: tariff.est });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.put('/:id', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { min, perkg, est } = req.body;
    const update = {};
    if (min !== undefined) update.min = min;
    if (perkg !== undefined) update.perkg = perkg;
    if (est !== undefined) update.est = est;

    const tariff = await Tariff.findByIdAndUpdate(req.params.id, update, { new: true }).lean();
    if (!tariff) return res.status(404).json({ message: 'Tarif tidak ditemukan' });
    res.json({ tariff_id: tariff._id, key: tariff.key, asal: tariff.asal, tujuan: tariff.tujuan, min: tariff.min, perkg: tariff.perkg, est: tariff.est });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/import', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { tariffs } = req.body;
    if (!Array.isArray(tariffs) || tariffs.length === 0) {
      return res.status(400).json({ message: 'Data tarif kosong atau tidak valid' });
    }

    const bulkOps = tariffs.map(t => ({
      updateOne: {
        filter: { key: t.key },
        update: { $set: { key: t.key, asal: t.asal, tujuan: t.tujuan, min: t.min, perkg: t.perkg, est: t.est } },
        upsert: true,
      },
    }));

    const result = await Tariff.bulkWrite(bulkOps, { ordered: false });
    const total = result.upsertedCount + result.matchedCount;

    res.json({ message: `Berhasil mengimpor ${total} tarif`, count: total });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
