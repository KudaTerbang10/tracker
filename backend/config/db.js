const dns = require('dns');
const mongoose = require('mongoose');

dns.setServers(['8.8.8.8', '1.1.1.1']);

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI, {
      serverSelectionTimeoutMS: 10000,
    });
    console.log(`MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`MongoDB Error: ${error.message}`);
    console.error('Pastikan:');
    console.error('  1. URI di .env sudah benar');
    console.error('  2. IP Anda sudah diwhitelist di MongoDB Atlas (Network Access)');
    console.error('  3. Atau gunakan MongoDB lokal: uncomment MONGO_URI di .env');
    process.exit(1);
  }
};

module.exports = connectDB;
