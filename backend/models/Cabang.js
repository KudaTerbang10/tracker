const mongoose = require('mongoose');

const cabangSchema = new mongoose.Schema({
  kode: { type: String, required: true, unique: true, uppercase: true, minlength: 3, maxlength: 3 },
  name: { type: String, required: true },
  address: { type: String, required: true },
  phone: { type: String, required: true },
  kota: { type: String, default: '' },
  is_active: { type: Boolean, default: true },
  lokasi: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [] },
  },
}, { timestamps: true });

module.exports = mongoose.model('Cabang', cabangSchema);
