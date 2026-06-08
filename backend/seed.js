require('dotenv').config();
const dns = require('dns');
const mongoose = require('mongoose');

dns.setServers(['8.8.8.8', '1.1.1.1']);

const User = require('./models/User');
const Konter = require('./models/Konter');
const Gudang = require('./models/Gudang');
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
      { kode: 'CKG', name: 'Hira Express Cengkareng', address: 'Jl. Bojong Raya No. 97, Rawa Buaya, Cengkareng, Jakarta Barat 11740', phone: '(021)-5814326' },
      { kode: 'MGB', name: 'Hira Express Mangga Besar', address: 'Jl. Mangga Besar 4 M No. 50, Kec. Taman Sari, Jakarta Barat 11150', phone: '(021)-6590993' },
      { kode: 'JMB', name: 'Hira Express Jelambar', address: 'Jl. Penerangan No. 51, Jelambar, Kec. Grogol, Jakarta Barat 11460', phone: '(021)-6570758' },
      { kode: 'CKU', name: 'Hira Express Cakung', address: 'Jl. Komarudin Lama 107 Pulo Gebang, Cakung, Jakarta Timur 13950', phone: '(021)-86608630' },
      { kode: 'MTA', name: 'Hira Express Metro Tanah Abang', address: 'Jl. Kebon Kacang 1 (Pusat Grosir Metro Tanah Abang, Pintu Keluar Kebon Kacang 1), Jakarta Pusat 10240', phone: '0858-4293-6780' },
      { kode: 'PTA', name: 'Hira Express Pasar Tanah Abang', address: 'Lobby Barat Blok B Pasar Tanah Abang, Jakarta Pusat', phone: '0858-4293-6780' },
      { kode: 'MDU', name: 'Hira Express ITC Mangga Dua', address: 'ITC Mangga Dua Raya, Lantai Dasar Blok E1 No. 12, Jl. Mangga Dua Raya, Jakarta Utara 14430', phone: '(021)-62300314' },
      { kode: 'JTN', name: 'Hira Express Jatinegara', address: 'Pintu Masuk Gedung Parkir Pasar Jatinegara, Jl. Raya Jatinegara Barat, Jakarta Timur 13320', phone: '(021)-8519589' },
      { kode: 'GMB', name: 'Hira Express Gambir', address: 'Jl. Alaydrus No. 16, Petojo Utara, Kec. Gambir, Jakarta Pusat 10130', phone: '(021)-63868028' },
      { kode: 'MMN', name: 'Hira Express Mas Mansyur', address: 'Jl. KH. Mas Mansyur No. 15D, Kec. Tanah Abang, Jakarta Pusat 10240', phone: '(021)-1905815' },
      { kode: 'ASK', name: 'Hira Express Asemka', address: 'Pusat Grosir Asemka, Pasar Pagi, Parkir Mobil Lantai Dasar, Jakarta Barat 11110', phone: '08112696716' },
    ]);
    console.log(`Created ${cabangs.length} cabangs`);

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
      { name: 'Admin Cabang Cengkareng', email: 'cabang@ekspedisi.id', password: 'cabang123', phone: '0810000006', role: 'admin_cabang', cabang_id: cabangs[0]._id },
    ];

    const users = await User.insertMany(usersData);
    console.log(`Created ${users.length} users`);

    console.log('\n=== AKUN LOGIN ===');
    console.log('Super Admin       | superadmin@ekspedisi.id | admin123');
    console.log('Admin Konter      | konter@ekspedisi.id     | konter123');
    console.log('Staff Gudang      | gudang@ekspedisi.id     | gudang123');
    console.log('Admin Cabang      | cabang@ekspedisi.id     | cabang123');
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
