const express = require('express');
const Transaction = require('../models/Transaction');

const router = express.Router();

router.get('/:no_resi', async (req, res) => {
  try {
    const tx = await Transaction.findOne({ no_resi: req.params.no_resi }).lean();

    if (!tx) {
      return res.status(404).json({ message: 'Resi tidak ditemukan' });
    }

    // Map old admin_konter to created_by for backward compatibility
    if (tx.admin_konter && !tx.created_by) {
      tx.created_by = {
        user_id: tx.admin_konter.user_id,
        name: tx.admin_konter.name,
        role: 'admin_konter',
        konter_id: tx.admin_konter.konter_id,
        konter_name: tx.admin_konter.konter_name || '',
        gudang_id: null,
        gudang_name: '',
      };
    }
    delete tx.admin_konter;

    res.json(tx);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
