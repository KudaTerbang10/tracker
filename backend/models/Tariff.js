const mongoose = require('mongoose');

const tariffSchema = new mongoose.Schema({
  key: { type: String, required: true, unique: true },
  asal: { type: String, required: true },
  tujuan: { type: String, required: true },
  min: { type: Number, required: true },
  perkg: { type: Number, required: true },
  est: { type: String, required: true },
}, { timestamps: true });

// 🚀 Optimasi pencarian & sorting tariff by asal + tujuan
tariffSchema.index({ asal: 1, tujuan: 1 });

module.exports = mongoose.model('Tariff', tariffSchema);
