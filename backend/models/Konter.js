const mongoose = require('mongoose');

const konterSchema = new mongoose.Schema({
  kode_singkat: { type: String, required: true, unique: true, uppercase: true, minlength: 3, maxlength: 3 },
  name: { type: String, required: true },
  address: { type: String, required: true },
  phone: { type: String, required: true },
  is_active: { type: Boolean, default: true },
}, { timestamps: true });

module.exports = mongoose.model('Konter', konterSchema);
