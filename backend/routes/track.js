const express = require('express');
const Transaction = require('../models/Transaction');

const router = express.Router();

router.get('/:no_resi', async (req, res) => {
  try {
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
