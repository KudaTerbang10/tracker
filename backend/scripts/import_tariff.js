require('dotenv').config();
const path = require('path');
const fs = require('fs');
const dns = require('dns');
const mongoose = require('mongoose');

dns.setServers(['8.8.8.8', '1.1.1.1']);

const Tariff = require('../models/Tariff');

async function importTariff() {
  try {
    await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 10000 });
    console.log('Connected to MongoDB');

    const jsonPath = path.resolve(__dirname, '../../assets/tariff.json');
    console.log('Reading:', jsonPath);
    const raw = fs.readFileSync(jsonPath, 'utf-8');
    const data = JSON.parse(raw);

    const entries = Object.entries(data);
    let imported = 0;
    const BATCH_SIZE = 500;

    for (let i = 0; i < entries.length; i += BATCH_SIZE) {
      const batch = entries.slice(i, i + BATCH_SIZE);
      const bulkOps = [];

      for (const [key, value] of batch) {
        const [asal, tujuan] = key.split('|');
        if (!asal || !tujuan) {
          console.warn(`Skipping invalid key: ${key}`);
          continue;
        }
        bulkOps.push({
          updateOne: {
            filter: { key },
            update: { $set: { key, asal, tujuan, min: value.min, perkg: value.perkg, est: value.est } },
            upsert: true,
          },
        });
      }

      if (bulkOps.length > 0) {
        const result = await Tariff.bulkWrite(bulkOps, { ordered: false });
        imported += result.upsertedCount + result.matchedCount;
        console.log(`  Batch ${Math.floor(i / BATCH_SIZE) + 1}: ${result.upsertedCount + result.matchedCount} processed`);
      }
    }

    console.log(`Imported ${imported} of ${entries.length} tariffs`);

    await mongoose.disconnect();
    console.log('Import completed!');
    process.exit(0);
  } catch (error) {
    console.error('Import error:', error.message);
    process.exit(1);
  }
}

importTariff();
