const mongoose = require('mongoose');

const tariffSchema = new mongoose.Schema({
  key: { type: String, required: true, unique: true },
  asal: { type: String, required: true },
  tujuan: { type: String, required: true },
  min: { type: Number, required: true },
  perkg: { type: Number, required: true },
  est: { type: String, required: true },
}, { timestamps: true });

module.exports = mongoose.model('Tariff', tariffSchema);
