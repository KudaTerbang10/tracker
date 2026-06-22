const Counter = require('../models/Counter');

async function generateNoManifest() {
  const now = new Date();
  const yyyy = now.getFullYear();
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const dd = String(now.getDate()).padStart(2, '0');
  const dateStr = `${yyyy}${mm}${dd}`;

  const counter = await Counter.findOneAndUpdate(
    { _id: `manifest_${dateStr}` },
    { $inc: { seq: 1 } },
    { new: true, upsert: true },
  );

  const seq = String(counter.seq).padStart(4, '0');
  return `MAN-${dateStr}-${seq}`;
}

module.exports = generateNoManifest;
