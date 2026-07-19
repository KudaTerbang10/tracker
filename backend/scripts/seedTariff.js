require('dotenv').config();
const fs = require('fs');
const path = require('path');
const dns = require('dns');
const mongoose = require('mongoose');

dns.setServers(['8.8.8.8', '1.1.1.1']);

const Tariff = require('../models/Tariff');

const TARIFF_FILE = path.join(__dirname, '..', '..', 'assets', 'tariff.json');

async function seedTariff() {
  try {
    const raw = fs.readFileSync(TARIFF_FILE, 'utf-8');
    const data = JSON.parse(raw);

    await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 10000 });
    console.log('Connected to MongoDB');

    const docs = Object.entries(data).map(([key, v]) => {
      const [asal, tujuan] = key.split('|');
      return {
        key,
        asal: asal.toLowerCase().trim(),
        tujuan: tujuan.toLowerCase().trim(),
        min: v.min,
        perkg: v.perkg,
        est: v.est,
      };
    });

    const bulkOps = docs.map(d => ({
      updateOne: {
        filter: { key: d.key },
        update: { $set: d },
        upsert: true,
      },
    }));

    const result = await Tariff.bulkWrite(bulkOps, { ordered: false });
    const total = result.upsertedCount + result.modifiedCount + result.matchedCount;
    console.log(`Processed ${docs.length} tariff entries (inserted: ${result.upsertedCount}, modified: ${result.modifiedCount})`);

    await mongoose.disconnect();
    console.log('Tariff seed completed!');
    process.exit(0);
  } catch (error) {
    console.error('Tariff seed error:', error.message);
    process.exit(1);
  }
}

seedTariff();
