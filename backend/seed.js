require('dotenv').config();
const dns = require('dns');
const mongoose = require('mongoose');

dns.setServers(['8.8.8.8', '1.1.1.1']);

const User = require('./models/User');
const Konter = require('./models/Konter');
const Gudang = require('./models/Gudang');

async function seed() {
  try {
    await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 10000 });
    console.log('Connected to MongoDB');

    await Promise.all([
      User.deleteMany({}),
      Konter.deleteMany({}),
      Gudang.deleteMany({}),
    ]);
    console.log('Cleared existing data');

    const konters = await Konter.insertMany([
      { kode_singkat: 'JKP', name: 'Konter Jakarta Pusat', address: 'Jl. Sudirman No.10, Jakarta', phone: '021-123456' },
      { kode_singkat: 'BDG', name: 'Konter Bandung', address: 'Jl. Asia Afrika No.5, Bandung', phone: '022-654321' },
      { kode_singkat: 'SBY', name: 'Konter Surabaya', address: 'Jl. Tunjungan No.12, Surabaya', phone: '031-789012' },
    ]);
    console.log(`Created ${konters.length} konters`);

    const gudangs = await Gudang.insertMany([
      { kode: 'GDG-CKG', name: 'Gudang Cakung', address: 'Jl. Raya Cakung KM 5, Jakarta Timur', phone: '021-111222' },
      { kode: 'GDG-BDG', name: 'Gudang Bandung', address: 'Jl. Soekarno-Hatta No.88, Bandung', phone: '022-333444' },
      { kode: 'GDG-SBY', name: 'Gudang Surabaya', address: 'Jl. Margomulyo No.20, Surabaya', phone: '031-555666' },
    ]);
    console.log(`Created ${gudangs.length} gudangs`);

    const usersData = [
      { name: 'Super Admin', email: 'superadmin@ekspedisi.id', password: 'admin123', phone: '0810000001', role: 'super_admin' },
      { name: 'Ahmad Konter', email: 'konter@ekspedisi.id', password: 'konter123', phone: '0810000002', role: 'admin_konter', konter_id: konters[0]._id },
      { name: 'Rudi Gudang', email: 'gudang@ekspedisi.id', password: 'gudang123', phone: '0810000003', role: 'staff_gudang', gudang_id: gudangs[0]._id },
      { name: 'Hendra Driver', email: 'driver@ekspedisi.id', password: 'driver123', phone: '0810000004', role: 'driver' },
      { name: 'Budi Driver', email: 'driver2@ekspedisi.id', password: 'driver123', phone: '0810000005', role: 'driver' },
    ];

    const users = await User.insertMany(usersData);
    console.log(`Created ${users.length} users`);

    console.log('\n=== AKUN LOGIN ===');
    console.log('Super Admin    | superadmin@ekspedisi.id | admin123');
    console.log('Admin Konter   | konter@ekspedisi.id     | konter123');
    console.log('Staff Gudang   | gudang@ekspedisi.id     | gudang123');
    console.log('Driver 1       | driver@ekspedisi.id     | driver123');
    console.log('Driver 2       | driver2@ekspedisi.id    | driver123');
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
