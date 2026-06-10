require('dotenv').config();
const dns = require('dns');
const mongoose = require('mongoose');

dns.setServers(['8.8.8.8', '1.1.1.1']);

const User = require('./models/User');
const Cabang = require('./models/Cabang');

async function seed() {
  try {
    await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 10000 });
    console.log('Connected to MongoDB');

    await Promise.all([
      User.deleteMany({}),
      Konter.deleteMany({}),
      Gudang.deleteMany({}),
      Cabang.deleteMany({}),
    ]);
    console.log('Cleared existing data');

    const cabangs = await Cabang.insertMany([
      { kode: 'CKG', name: 'Cengkareng', address: 'Jl. Raya Cengkareng No.1, Jakarta Barat', phone: '021-999888' },
      { kode: 'BDG', name: 'Bandung', address: 'Jl. Asia Afrika No.10, Bandung', phone: '022-777888' },
      { kode: 'SBY', name: 'Surabaya', address: 'Jl. Tunjungan No.5, Surabaya', phone: '031-444555' },
    ]);
    console.log(`Created ${cabangs.length} cabangs`);

    const usersData = [
      { name: 'Super Admin', email: 'superadmin@ekspedisi.id', password: 'admin123', phone: '0810000001', role: 'super_admin' },
      { name: 'Admin Cabang Cengkareng', email: 'cabang@ekspedisi.id', password: 'cabang123', phone: '0810000006', role: 'admin_cabang', cabang_id: cabangs[0]._id },
      { name: 'Admin Cabang Bandung', email: 'cabangbdg@ekspedisi.id', password: 'cabang123', phone: '0810000007', role: 'admin_cabang', cabang_id: cabangs[1]._id },
      { name: 'Admin Cabang Surabaya', email: 'cabangsby@ekspedisi.id', password: 'cabang123', phone: '0810000008', role: 'admin_cabang', cabang_id: cabangs[2]._id },
      { name: 'Hendra Driver', email: 'driver@ekspedisi.id', password: 'driver123', phone: '0810000004', role: 'driver' },
      { name: 'Budi Driver', email: 'driver2@ekspedisi.id', password: 'driver123', phone: '0810000005', role: 'driver' },
    ];

    const users = await User.insertMany(usersData);
    console.log(`Created ${users.length} users`);

    console.log('\n=== AKUN LOGIN ===');
    console.log('Super Admin       | superadmin@ekspedisi.id | admin123');
    console.log('Admin Cabang CKG  | cabang@ekspedisi.id     | cabang123');
    console.log('Admin Cabang BDG  | cabangbdg@ekspedisi.id  | cabang123');
    console.log('Admin Cabang SBY  | cabangsby@ekspedisi.id  | cabang123');
    console.log('Driver 1          | driver@ekspedisi.id     | driver123');
    console.log('Driver 2          | driver2@ekspedisi.id    | driver123');
    console.log('==================\n');

    await mongoose.disconnect();
    console.log('Seed completed!');
    process.exit(0);
  } catch (error) {
    console.error('Seed error:', error.message);
    console.error('Pastikan IP Anda sudah diwhitelist di MongoDB Atlas Network Access');
    process.exit(1);
  }
}

seed();
