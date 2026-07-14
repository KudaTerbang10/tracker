const express = require('express');
const Transaction = require('../models/Transaction');
const Manifest = require('../models/Manifest');
const User = require('../models/User');
const Cabang = require('../models/Cabang');
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');

const router = express.Router();

router.get('/traffic', auth, rbac('super_admin'), async (req, res) => {
  try {
    const { start, end } = req.query;
    const match = {};
    if (start || end) {
      match.createdAt = {};
      if (start) match.createdAt.$gte = new Date(start);
      if (end) match.createdAt.$lte = new Date(end);
    }
    match.jenis_masalah = { $nin: ['hilang'] };

    const traffic = await Transaction.aggregate([
      { $match: match },
      { $group: { _id: '$kode_gerai', total: { $sum: 1 } } },
      { $sort: { total: -1 } },
      { $limit: 10 },
    ]);

    res.json({ data: traffic.map(t => ({ kode_gerai: t._id, total: t.total })) });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/customers-top', auth, rbac('super_admin'), async (req, res) => {
  try {
    const month = parseInt(req.query.month);
    const year = parseInt(req.query.year);
    const match = {};
    if (month && year && month >= 1 && month <= 12) {
      match.createdAt = {
        $gte: new Date(year, month - 1, 1),
        $lte: new Date(year, month, 0, 23, 59, 59, 999),
      };
    }
    match.jenis_masalah = { $nin: ['hilang'] };

    const topCustomers = await Transaction.aggregate([
      ...(Object.keys(match).length > 0 ? [{ $match: match }] : []),
      { $group: { _id: { name: '$pengirim.name', phone: '$pengirim.phone' }, total: { $sum: 1 }, total_biaya: { $sum: '$paket.biaya_kirim' } } },
      { $sort: { total: -1 } },
      { $limit: 10 },
      { $project: { _id: 0, name: '$_id.name', phone: '$_id.phone', total: 1, total_biaya: 1 } },
    ]);

    res.json({ data: topCustomers });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/summary', auth, rbac('super_admin'), async (req, res) => {
  try {
    const [totalTransaksi, statusCount, totalDriver] = await Promise.all([
      Transaction.estimatedDocumentCount(),
      Transaction.aggregate([{ $group: { _id: '$status_saat_ini', count: { $sum: 1 } } }, { $sort: { _id: 1 } }]),
      User.countDocuments({ role: 'driver', is_active: true }),
    ]);

    res.json({ total_transaksi: totalTransaksi, status_distribution: statusCount, total_driver: totalDriver });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/per-cabang', auth, rbac('super_admin'), async (req, res) => {
  try {
    const month = parseInt(req.query.month);
    const year = parseInt(req.query.year);
    if (!month || !year || month < 1 || month > 12)
      return res.status(400).json({ message: 'month (1-12) and year required' });

    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59, 999);

    const data = await Transaction.aggregate([
      { $match: { createdAt: { $gte: startDate, $lte: endDate }, jenis_masalah: { $nin: ['hilang'] } } },
      { $group: { _id: '$kode_gerai', total_resi: { $sum: 1 }, total_biaya: { $sum: '$paket.biaya_kirim' } } },
      { $lookup: { from: 'cabangs', localField: '_id', foreignField: 'kode', as: 'cabang' } },
      { $addFields: { cabang_name: { $ifNull: [{ $arrayElemAt: ['$cabang.name', 0] }, '$_id'] } } },
      { $project: { _id: 0, kode_gerai: '$_id', cabang_name: 1, total_resi: 1, total_biaya: 1 } },
      { $sort: { total_resi: -1 } },
    ]);

    res.json({ data, month, year });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/wajib-setor', auth, rbac('super_admin', 'admin_cabang'), async (req, res) => {
  try {
    const month = parseInt(req.query.month);
    const year = parseInt(req.query.year);
    if (!month || !year || month < 1 || month > 12)
      return res.status(400).json({ message: 'month (1-12) and year required' });

    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59, 999);

    // Cash dihitung berdasarkan createdAt (cash langsung paid saat dibuat,
    // tidak punya pembayaran_dikonfirmasi_pada).
    // COD & Tempo dihitung berdasarkan pembayaran_dikonfirmasi_pada
    // (bulan uang benar-benar lunas/tertagih), agar selaras dengan waktu
    // uang masuk ke cabang untuk disetor.

    // Grup A: Cash (basis createdAt) -> cabang asal
    const [cashAgg, asalAgg, lastMileAgg] = await Promise.all([
      Transaction.aggregate([
        {
          $match: {
            createdAt: { $gte: startDate, $lte: endDate },
            jenis_masalah: { $ne: 'hilang' },
            'created_by.cabang_id': { $exists: true, $ne: null },
            jenis_pembayaran: 'cash',
          },
        },
        {
          $group: {
            _id: '$created_by.cabang_id',
            cash: { $sum: '$paket.biaya_kirim' },
          },
        },
      ]),
      // Grup B: Tempo + COD retur (basis pembayaran_dikonfirmasi_pada) -> cabang asal
      Transaction.aggregate([
        {
          $match: {
            pembayaran_dikonfirmasi_pada: { $gte: startDate, $lte: endDate },
            jenis_masalah: { $ne: 'hilang' },
            'created_by.cabang_id': { $exists: true, $ne: null },
            jenis_pembayaran: { $in: ['cod', 'tempo'] },
            status_pembayaran: 'paid',
          },
        },
        {
          $group: {
            _id: '$created_by.cabang_id',
            tempo: { $sum: { $cond: [{ $eq: ['$jenis_pembayaran', 'tempo'] }, '$paket.biaya_kirim', 0] } },
            cod_retur: {
              $sum: {
                $cond: [
                  { $and: [{ $eq: ['$jenis_pembayaran', 'cod'] }, { $eq: ['$jenis_masalah', 'gagal_kirim'] }] },
                  '$paket.biaya_kirim',
                  0,
                ],
              },
            },
          },
        },
      ]),
      // Grup C: COD sukses (basis pembayaran_dikonfirmasi_pada) -> cabang last mile
      Transaction.aggregate([
        {
          $match: {
            pembayaran_dikonfirmasi_pada: { $gte: startDate, $lte: endDate },
            jenis_pembayaran: 'cod',
            status_pembayaran: 'paid',
            jenis_masalah: { $nin: ['hilang', 'gagal_kirim'] },
            cod_cabang_id: { $exists: true, $ne: null },
          },
        },
        {
          $group: {
            _id: '$cod_cabang_id',
            cod_lastmile: { $sum: '$paket.biaya_kirim' },
          },
        },
      ]),
    ]);

    // Gabungkan per cabang
    const map = new Map();
    const push = (id, patch) => {
      const key = id?.toString();
      if (!key) return;
      const cur = map.get(key) || { cash: 0, tempo: 0, cod_retur: 0, cod_lastmile: 0 };
      Object.assign(cur, patch);
      map.set(key, cur);
    };
    for (const r of cashAgg) push(r._id, { cash: r.cash });
    for (const r of asalAgg) push(r._id, { tempo: r.tempo, cod_retur: r.cod_retur });
    for (const r of lastMileAgg) push(r._id, { cod_lastmile: r.cod_lastmile });

    const cabangIds = [...map.keys()];
    const cabangs = await Cabang.find({ _id: { $in: cabangIds } }, 'kode name').lean();
    const cabangInfo = new Map(cabangs.map((c) => [c._id.toString(), c]));

    const data = [...map.entries()]
      .map(([id, v]) => {
        const info = cabangInfo.get(id) || {};
        const cod_total = v.cod_lastmile + v.cod_retur;
        const total = v.cash + cod_total + v.tempo;
        return {
          cabang_id: id,
          kode_cabang: info.kode || '',
          nama_cabang: info.name || 'Cabang',
          cash: v.cash,
          cod_lastmile: v.cod_lastmile,
          cod_retur: v.cod_retur,
          cod_total,
          tempo: v.tempo,
          total,
        };
      })
      .sort((a, b) => b.total - a.total);

    // Admin cabang hanya boleh melihat omset cabangnya sendiri
    const filteredData =
      req.user.role === 'admin_cabang' && req.user.cabang_id
        ? data.filter((d) => d.cabang_id === req.user.cabang_id.toString())
        : data;

    res.json({ data: filteredData, month, year });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/routes-top', auth, rbac('super_admin'), async (req, res) => {
  try {
    const month = parseInt(req.query.month);
    const year = parseInt(req.query.year);
    if (!month || !year || month < 1 || month > 12)
      return res.status(400).json({ message: 'month (1-12) and year required' });

    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59, 999);

    const data = await Transaction.aggregate([
      { $match: { createdAt: { $gte: startDate, $lte: endDate }, jenis_masalah: { $nin: ['hilang'] } } },
      {
        $group: {
          _id: { asal: '$kode_gerai', tujuan: '$penerima.kota' },
          total_resi: { $sum: 1 },
          total_biaya: { $sum: '$paket.biaya_kirim' },
        },
      },
      { $sort: { total_resi: -1 } },
      { $limit: 10 },
      {
        $lookup: {
          from: 'cabangs',
          localField: '_id.asal',
          foreignField: 'kode',
          as: 'cabang',
        },
      },
      {
        $addFields: {
          asal_nama: { $ifNull: [{ $arrayElemAt: ['$cabang.name', 0] }, '$_id.asal'] },
        },
      },
      {
        $project: {
          _id: 0,
          asal_kode: '$_id.asal',
          asal_nama: 1,
          tujuan_kota: '$_id.tujuan',
          total_resi: 1,
          total_biaya: 1,
        },
      },
    ]);

    res.json({ data, month, year });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/drivers', auth, rbac('super_admin'), async (req, res) => {
  try {
    const month = parseInt(req.query.month);
    const year = parseInt(req.query.year);
    if (!month || !year || month < 1 || month > 12)
      return res.status(400).json({ message: 'month (1-12) and year required' });

    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59, 999);

    const data = await Transaction.aggregate([
      {
        $match: {
          createdAt: { $gte: startDate, $lte: endDate },
          // Filter dokumen yang punya tracking_log dengan status keluar_cabang + driver
          // SEBELUM $unwind, supaya dokumen tanpa data relevan tidak ikut di-unwind
          'tracking_logs': {
            $elemMatch: {
              status: 'keluar_cabang',
              'driver_ditugaskan.user_id': { $exists: true, $ne: null },
            },
          },
        },
      },
      { $unwind: '$tracking_logs' },
      {
        $match: {
          'tracking_logs.status': 'keluar_cabang',
          'tracking_logs.driver_ditugaskan': { $exists: true, $ne: null },
        },
      },
      {
        $group: {
          _id: '$tracking_logs.driver_ditugaskan.user_id',
          driver_name: { $first: '$tracking_logs.driver_ditugaskan.nama' },
          driver_kontak: { $first: '$tracking_logs.driver_ditugaskan.kontak' },
          total: { $sum: 1 },
          antar_cabang: {
            $sum: {
              $cond: [{ $eq: ['$tracking_logs.tujuan.tipe', 'cabang'] }, 1, 0],
            },
          },
          antar_penerima: {
            $sum: {
              $cond: [{ $eq: ['$tracking_logs.tujuan.tipe', 'penerima'] }, 1, 0],
            },
          },
        },
      },
      {
        $project: {
          _id: 1,
          driver_id: '$_id',
          driver_name: 1,
          driver_kontak: 1,
          total: 1,
          antar_cabang: 1,
          antar_penerima: 1,
        },
      },
      { $sort: { total: -1 } },
    ]);

    res.json({ data, month, year });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/driver-performance', auth, rbac('super_admin'), async (req, res) => {
  try {
    const month = parseInt(req.query.month);
    const year = parseInt(req.query.year);
    if (!month || !year || month < 1 || month > 12)
      return res.status(400).json({ message: 'month (1-12) and year required' });

    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59, 999);

    const data = await Manifest.aggregate([
      {
        $match: {
          status: 'selesai',
          completed_at: { $gte: startDate, $lte: endDate },
          'driver.user_id': { $exists: true, $ne: null },
        },
      },
      {
        $group: {
          _id: {
            tipe: '$tipe_manifest',
            driver_id: '$driver.user_id',
          },
          driver_name: { $first: '$driver.name' },
          total_manifest: { $sum: 1 },
          total_work_unit: { $sum: '$work_unit' },
          total_resi: { $sum: '$total_resi' },
        },
      },
      {
        $group: {
          _id: '$_id.tipe',
          drivers: {
            $push: {
              driver_id: '$_id.driver_id',
              driver_name: '$driver_name',
              total_manifest: '$total_manifest',
              total_work_unit: '$total_work_unit',
              total_resi: '$total_resi',
            },
          },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    const result = { month, year, antar_cabang: [], antar_penerima: [] };
    for (const group of data) {
      group.drivers.sort((a, b) => b.total_work_unit - a.total_work_unit);
      if (group._id === 'antar_cabang') result.antar_cabang = group.drivers;
      else if (group._id === 'antar_penerima') result.antar_penerima = group.drivers;
    }

    res.json(result);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
