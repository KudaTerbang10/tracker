const Counter = require('../models/Counter');

async function generateResi(kodeGerai) {
  const today = new Date();
  const yyyy = today.getFullYear().toString();
  const mm = String(today.getMonth() + 1).padStart(2, '0');
  const dd = String(today.getDate()).padStart(2, '0');
  const dateStr = `${yyyy}${mm}${dd}`;

  const key = `${kodeGerai}-${dateStr}`;

  const counter = await Counter.findOneAndUpdate(
    { _id: key },
    { $inc: { seq: 1 } },
    { new: true, upsert: true }
  );

  const seq = String(counter.seq).padStart(4, '0');
  return `${kodeGerai}-${dateStr}-${seq}`;
}

module.exports = generateResi;
