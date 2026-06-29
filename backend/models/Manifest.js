const mongoose = require('mongoose');

const manifestSchema = new mongoose.Schema({
  no_manifest: {
    type: String,
    required: true,
    unique: true,
  },

  created_by: {
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    name: { type: String, required: true },
    cabang_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Cabang', required: true },
    cabang_name: { type: String, required: true },
  },

  driver: {
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    name: { type: String, required: true },
    phone: { type: String, default: '' },
  },

  tujuan: {
    tipe: { type: String, enum: ['cabang', 'penerima'], required: true },
    cabang_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Cabang', default: null },
    nama: { type: String, required: true },
    lokasi: {
      type: { type: String, enum: ['Point'], default: null },
      coordinates: { type: [Number], default: [] },
    },
  },

  asal_cabang_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Cabang', required: true },
  asal_cabang_name: { type: String, required: true },

  tipe_manifest: {
    type: String,
    enum: ['antar_cabang', 'antar_penerima'],
    required: true,
  },

  work_unit: { type: Number, required: true },
  total_resi: { type: Number, required: true },
  jumlah_koli: { type: Number, required: true },
  total_berat: { type: Number, default: 0 },

  status: {
    type: String,
    enum: ['dibuat', 'dalam_perjalanan', 'selesai'],
    default: 'dibuat',
  },

  completed_at: { type: Date, default: null },
}, { timestamps: true });

manifestSchema.index({ 'created_by.user_id': 1, createdAt: -1 });
manifestSchema.index({ 'driver.user_id': 1, status: 1 });
manifestSchema.index({ asal_cabang_id: 1, createdAt: -1 });
manifestSchema.index({ status: 1, createdAt: -1 });

// 🚀 Optimasi aggregate analytics driver-performance (status selesai + completed_at range)
manifestSchema.index({ status: 1, completed_at: -1, 'driver.user_id': 1 });

module.exports = mongoose.model('Manifest', manifestSchema);
