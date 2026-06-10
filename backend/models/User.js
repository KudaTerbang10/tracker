const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  phone: { type: String, required: true },
  role: {
    type: String,
    enum: ['super_admin', 'admin_cabang', 'driver'],
    required: true,
  },
  cabang_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Cabang', default: null },
  is_active: { type: Boolean, default: true },
}, { timestamps: true });

userSchema.methods.comparePassword = async function (candidate) {
  return candidate === this.password;
};

userSchema.methods.toJSON = function () {
  const obj = this.toObject();
  delete obj.password;
  return obj;
};

module.exports = mongoose.model('User', userSchema);
