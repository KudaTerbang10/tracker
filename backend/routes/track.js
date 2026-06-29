const express = require('express');
const Transaction = require('../models/Transaction');

const router = express.Router();

const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW = 60_000;
const RATE_LIMIT_MAX = 30;

function getRateLimitInfo(ip) {
  const now = Date.now();
  let entry = rateLimitMap.get(ip);
  if (!entry || now - entry.windowStart > RATE_LIMIT_WINDOW) {
    entry = { windowStart: now, count: 0 };
    rateLimitMap.set(ip, entry);
  }
  return entry;
}

setInterval(() => {
  const now = Date.now();
  for (const [ip, entry] of rateLimitMap) {
    if (now - entry.windowStart > RATE_LIMIT_WINDOW) {
      rateLimitMap.delete(ip);
    }
  }
}, 60_000).unref();

router.get('/:no_resi', async (req, res) => {
  try {
    const ip = req.ip || req.connection?.remoteAddress || 'unknown';
    const rate = getRateLimitInfo(ip);
    rate.count++;

    res.setHeader('X-RateLimit-Limit', RATE_LIMIT_MAX);
    res.setHeader('X-RateLimit-Remaining', Math.max(0, RATE_LIMIT_MAX - rate.count));
    res.setHeader('X-RateLimit-Reset', Math.ceil((rate.windowStart + RATE_LIMIT_WINDOW) / 1000));

    if (rate.count > RATE_LIMIT_MAX) {
      return res.status(429).json({
        message: 'Terlalu banyak permintaan. Silakan coba lagi dalam 1 menit.',
        retry_after_seconds: Math.ceil((rate.windowStart + RATE_LIMIT_WINDOW - Date.now()) / 1000),
      });
    }

    const tx = await Transaction.findOne({ no_resi: req.params.no_resi }).lean();

    if (!tx) {
      return res.status(404).json({ message: 'Resi tidak ditemukan' });
    }

    res.json(tx);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
