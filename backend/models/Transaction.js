const mongoose = require('mongoose');

const trackingLogSchema = new mongoose.Schema({
  status: {
    type: String,
    enum: ['diterima_cabang', 'keluar_cabang', 'proses_kirim', 'diterima'],
    required: true,
  },
  deskripsi: { type: String, default: '' },
  pelaku: {
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    name: { type: String, required: true },
    role: { type: String, required: true },
  },
  lokasi: {
    nama: { type: String, default: '' },
    tipe: { type: String, enum: ['cabang', ''], default: '' },
    cabang_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Cabang', default: null },
  },
  driver_ditugaskan: {
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    nama: { type: String, default: '' },
    kontak: { type: String, default: '' },
  },
  tujuan: {
    tipe: { type: String, enum: ['cabang', 'penerima', ''], default: '' },
    nama: { type: String, default: '' },
  },
  nama_penerima: { type: String, default: '' },
  timestamp: { type: Date, default: Date.now },
});

const transactionSchema = new mongoose.Schema({
  no_resi: { type: String, required: true, unique: true },
  kode_gerai: { type: String, required: true },
  barcode_data: { type: String, required: true },

  pengirim: {
    name: { type: String, required: true },
    phone: { type: String, required: true },
    address: { type: String, required: true },
  },
  penerima: {
    name: { type: String, required: true },
    phone: { type: String, required: true },
    address: { type: String, required: true },
    kecamatan: { type: String, default: '' },
    kota: { type: String, default: '' },
  },
  paket: {
    berat_kg: { type: Number, required: true },
    jumlah_koli: { type: Number, required: true },
    biaya_kirim: { type: Number, required: true },
  },

  created_by: {
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    name: { type: String, required: true },
    role: { type: String, required: true },
    cabang_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Cabang', default: null },
    cabang_name: { type: String, default: '' },
  },

  status_saat_ini: {
    type: String,
    enum: ['diterima_cabang', 'keluar_cabang', 'proses_kirim', 'diterima'],
    default: 'diterima_cabang',
  },

  nama_driver: { type: String, default: null },
  kontak_driver: { type: String, default: null },
  driver_user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },

  tujuan_selanjutnya: {
    tipe: { type: String, enum: ['cabang', 'penerima', null], default: null },
    cabang_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Cabang', default: null },
    nama: { type: String, default: null },
  },

  nama_penerima_akhir: { type: String, default: null },

  tracking_logs: [trackingLogSchema],
}, { timestamps: true });

transactionSchema.index({ status_saat_ini: 1 });
transactionSchema.index({ kode_gerai: 1, createdAt: -1 });
transactionSchema.index({ 'tracking_logs.pelaku.user_id': 1 });
transactionSchema.index({ 'tracking_logs.timestamp': -1 });

module.exports = mongoose.model('Transaction', transactionSchema);
