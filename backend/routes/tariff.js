const express = require('express');
const Tariff = require('../models/Tariff');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

router.get('/', auth, async (req, res) => {
  try {
    const { search } = req.query;
    let filter = {};
    if (search) {
      const re = new RegExp(search, 'i');
      filter = { $or: [{ asal: re }, { tujuan: re }] };
    }
    const tariffs = await Tariff.find(filter).sort({ asal: 1, tujuan: 1 }).lean();
    res.json({ data: tariffs.map(t => ({ tariff_id: t._id, key: t.key, asal: t.asal, tujuan: t.tujuan, min: t.min, perkg: t.perkg, est: t.est })) });
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

    let imported = 0;
    for (const t of tariffs) {
      await Tariff.findOneAndUpdate(
        { key: t.key },
        { key: t.key, asal: t.asal, tujuan: t.tujuan, min: t.min, perkg: t.perkg, est: t.est },
        { upsert: true, new: true }
      );
      imported++;
    }

    res.json({ message: `Berhasil mengimpor ${imported} tarif`, count: imported });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
