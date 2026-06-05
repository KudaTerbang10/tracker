const mongoose = require('mongoose');

const gudangSchema = new mongoose.Schema({
  kode: { type: String, required: true, unique: true },
  name: { type: String, required: true },
  address: { type: String, required: true },
  phone: { type: String, required: true },
  is_active: { type: Boolean, default: true },
}, { timestamps: true });

module.exports = mongoose.model('Gudang', gudangSchema);
