require('dotenv').config();
const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');

const authRoutes = require('./routes/auth');
const trackRoutes = require('./routes/track');
const transactionRoutes = require('./routes/transaction');
const driverRoutes = require('./routes/driver');
const gudangRoutes = require('./routes/gudang');
const userRoutes = require('./routes/user');
const konterRoutes = require('./routes/konter');
const cabangRoutes = require('./routes/cabang');
const analyticsRoutes = require('./routes/analytics');

const app = express();

app.use(cors());
app.use(express.json({ limit: '10mb' }));

app.use('/api/auth', authRoutes);
app.use('/api/track', trackRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/drivers', driverRoutes);
app.use('/api/gudangs', gudangRoutes);
app.use('/api/users', userRoutes);
app.use('/api/konters', konterRoutes);
app.use('/api/cabangs', cabangRoutes);
app.use('/api/analytics', analyticsRoutes);

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date() });
});

const PORT = process.env.PORT || 5000;

connectDB().then(() => {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
    console.log(`Akses dari HP: http://<IP_LAPTOP>:${PORT}/api/health`);
  });
});
