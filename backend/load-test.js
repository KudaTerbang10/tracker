/**
 * Load Test — 40 Cabang Full Flow
 *
 * Mensimulasikan beban 40 cabang aktif secara bersamaan:
 * login, create transaksi, batch scan keluar, driver terima,
 * reports, analytics, manifest, pembayaran.
 *
 * Jalankan: node load-test.js
 */
require('dotenv').config();
const http = require('http');

const API = 'http://localhost:5000';
const TIMEOUT = 30000;

// ─── Metrics Collector ────────────────────────────────────────
const metrics = {};
function record(label, ms, ok) {
  if (!metrics[label]) metrics[label] = { total: 0, ok: 0, fail: 0, times: [] };
  const m = metrics[label];
  m.total++;
  if (ok) m.ok++; else m.fail++;
  m.times.push(ms);
}

function summary() {
  console.log('\n' + '═'.repeat(72));
  console.log('  METRICS SUMMARY');
  console.log('═'.repeat(72));
  const labels = Object.keys(metrics).sort();
  for (const label of labels) {
    const m = metrics[label];
    const times = m.times.sort((a, b) => a - b);
    const avg = (times.reduce((s, t) => s + t, 0) / times.length).toFixed(1);
    const p50 = times[Math.floor(times.length * 0.5)].toFixed(1);
    const p95 = times[Math.floor(times.length * 0.95)].toFixed(1);
    const p99 = times[Math.floor(times.length * 0.99)].toFixed(1);
    const max = times[times.length - 1].toFixed(1);
    const rate = (m.ok / (times.reduce((s, t) => s + t, 0) / 1000)).toFixed(1);
    const errPct = (m.fail / m.total * 100).toFixed(1);
    console.log(
      `  ${label.padEnd(30)} ` +
      `OK:${String(m.ok).padStart(4)} Fail:${String(m.fail).padStart(3)} ` +
      `Err:${errPct.padStart(5)}% ` +
      `Avg:${avg.padStart(6)}ms ` +
      `p50:${p50.padStart(6)} p95:${p95.padStart(6)} p99:${p99.padStart(6)} ` +
      `Max:${max.padStart(6)} ` +
      `RPS:${rate}`
    );
  }
  console.log('═'.repeat(72));
}

// ─── HTTP Helpers ─────────────────────────────────────────────
function request(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const fullPath = path.startsWith('http') ? path : `/api${path}`;
    const url = new URL(fullPath, API);
    const opts = {
      method,
      hostname: url.hostname,
      port: url.port || 80,
      path: url.pathname + url.search,
      headers: { 'Content-Type': 'application/json' },
      timeout: TIMEOUT,
    };
    if (token) opts.headers['Authorization'] = `Bearer ${token}`;

    const req = http.request(opts, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, data });
        }
      });
    });
    req.on('error', (e) => reject(e));
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

function timed(label, fn) {
  const start = Date.now();
  return fn()
    .then((r) => { record(label, Date.now() - start, r.status < 500); return r; })
    .catch((e) => { record(label, Date.now() - start, false); throw e; });
}

// ─── Main Test Flow ───────────────────────────────────────────
async function main() {
  console.log('═══ LOAD TEST — 40 CABANG FULL FLOW ═══\n');
  const startAll = Date.now();

  // 1. Login super admin — dapatkan master data
  console.log('[1] Login super_admin...');
  const saRes = await timed('login.super_admin', () =>
    request('POST', '/auth/login', { email: 'superadmin@ekspedisi.id', password: 'admin123' })
  );
  if (saRes.status !== 200) { console.error('Gagal login super_admin:', saRes.data); process.exit(1); }
  const saToken = saRes.data.token;

  // 2. Dapatkan daftar cabang + users
  console.log('[2] Fetch cabangs & drivers...');
  const cabangsRes = await timed('fetch.cabangs', () =>
    request('GET', '/cabangs', null, saToken)
  );
  if (cabangsRes.status !== 200) { console.error('Gagal fetch cabangs:', cabangsRes.data); process.exit(1); }
  const cabangs = cabangsRes.data.data;
  console.log(`     ${cabangs.length} cabangs loaded`);

  const driversRes = await timed('fetch.drivers', () =>
    request('GET', '/drivers', null, saToken)
  );
  const drivers = driversRes.data?.data || [];
  console.log(`     ${drivers.length} drivers loaded`);

  // 3. Login all 40 admin cabang + 2 drivers secara paralel
  console.log('[3] Login 40 admin cabang + 2 drivers...');
  const adminTokens = {};
  const loginPromises = cabangs.map((c) =>
    request('POST', '/auth/login', { email: `${c.kode.toLowerCase()}@ekspedisi.id`, password: 'cabang123' })
      .then((r) => { if (r.status === 200) adminTokens[c.kode] = r.data.token; })
      .catch(() => {})
  );
  // Login drivers
  let driver1Token, driver2Token;
  const driverPromises = [
    request('POST', '/auth/login', { email: 'driver@ekspedisi.id', password: 'driver123' })
      .then((r) => { if (r.status === 200) driver1Token = r.data.token; }),
    request('POST', '/auth/login', { email: 'driver2@ekspedisi.id', password: 'driver123' })
      .then((r) => { if (r.status === 200) driver2Token = r.data.token; }),
  ];
  await Promise.all([...loginPromises, ...driverPromises]);
  const loggedIn = Object.keys(adminTokens).length;
  console.log(`     ${loggedIn}/40 admin cabang + ${driver1Token ? 1 : 0} driver login OK`);

  if (loggedIn < 10) { console.error('Terlalu sedikit admin login, batal.'); process.exit(1); }

  // ─── PHASE A: BULK CREATE TRANSACTIONS ────────────────────
  console.log('\n[4] PHASE A — Create transactions (20-30 per cabang)...');
  const allTransactions = []; // { no_resi, kode, token, cabang_id }
  const cabangCodes = Object.keys(adminTokens);
  const cabangMap = {}; cabangs.forEach(c => cabangMap[c.kode] = c);

  const kotaList = ['Jakarta', 'Bandung', 'Surabaya', 'Semarang', 'Yogyakarta', 'Solo', 'Malang', 'Bogor', 'Bekasi', 'Tangerang'];

  let createTotal = 0, createOk = 0, createFail = 0;
  const createBatchSize = 5; // 5 paralel per cabang per batch

  for (const kode of cabangCodes) {
    const token = adminTokens[kode];
    if (!token) continue;
    const count = 20 + Math.floor(Math.random() * 11); // 20-30

    for (let batch = 0; batch < count; batch += createBatchSize) {
      const batchSize = Math.min(createBatchSize, count - batch);
      const promises = [];
      for (let i = 0; i < batchSize; i++) {
        const penerimaKota = kotaList[Math.floor(Math.random() * kotaList.length)];
        const jenisPembayaran = ['cash', 'cash', 'cash', 'cod', 'tempo'][Math.floor(Math.random() * 5)];
        const body = {
          pengirim: { name: `Pengirim ${kode}-${batch+i}`, phone: `081${String(Math.floor(Math.random() * 1e9)).padStart(9, '0')}`, address: `Jl. Contoh No.${batch+i}, ${penerimaKota}` },
          penerima: { name: `Penerima ${kode}-${batch+i}`, phone: `082${String(Math.floor(Math.random() * 1e9)).padStart(9, '0')}`, address: `Jl. Tujuan No.${batch+i}, ${penerimaKota}`, kota: penerimaKota },
          paket: { berat_kg: 0.5 + Math.random() * 10, jumlah_koli: 1 + Math.floor(Math.random() * 5), biaya_kirim: 10000 + Math.floor(Math.random() * 50000) },
          jenis_pembayaran: jenisPembayaran,
          tempo_hari: jenisPembayaran === 'tempo' ? 14 : 0,
        };
        promises.push(
          timed('create.tx', () => request('POST', '/transactions', body, token))
            .then((r) => {
              if (r.status === 201 || r.status === 200) {
                allTransactions.push({ no_resi: r.data.no_resi, kode, cabang_id: cabangMap[kode]?.cabang_id });
                createOk++;
              } else { createFail++; }
              createTotal++;
            })
            .catch(() => { createFail++; createTotal++; })
        );
      }
      await Promise.allSettled(promises);
    }
    // Progress
    if (cabangCodes.indexOf(kode) % 10 === 0 || kode === cabangCodes[cabangCodes.length - 1]) {
      console.log(`     Create progress: ${createOk} OK / ${createFail} Fail / ${createTotal} total (last: ${kode})`);
    }
  }
  console.log(`     Create done: ${createOk} OK / ${createFail} Fail / ${createTotal} total`);

  if (allTransactions.length < 50) { console.error('Terlalu sedikit transaksi dibuat, batal.'); process.exit(1); }

  // ─── PHASE B: BATCH SCAN KELUAR ────────────────────────────
  console.log('\n[5] PHASE B — Batch scan keluar (2-3 driver dispatch per cabang)...');
  let batchOk = 0, batchFail = 0, batchTotal = 0;
  const driverIds = drivers.map(d => d.user_id);
  const driverNames = drivers.map(d => d.name);

  // Group transactions by cabang
  const txByCabang = {};
  for (const tx of allTransactions) {
    if (!txByCabang[tx.kode]) txByCabang[tx.kode] = [];
    txByCabang[tx.kode].push(tx.no_resi);
  }

  for (const [kode, noResiList] of Object.entries(txByCabang)) {
    const token = adminTokens[kode];
    if (!token) continue;
    const cabang = cabangMap[kode];

    // Split into 2-3 batches per cabang (cabang → cabang lain or penerima)
    const batches = [];
    const chunkSize = Math.max(3, Math.floor(noResiList.length / 3));
    for (let i = 0; i < noResiList.length; i += chunkSize) {
      batches.push(noResiList.slice(i, i + chunkSize));
    }

    for (const batch of batches) {
      // Pilih random tujuan (cabang lain atau penerima)
      const tipeTujuan = Math.random() > 0.3 ? 'cabang' : 'penerima';
      let cabangTujuanId = null;
      let cabangNamaManual = null;

      if (tipeTujuan === 'cabang') {
        const lain = cabangs.filter(c => c.kode !== kode);
        if (lain.length > 0) {
          const tujuan = lain[Math.floor(Math.random() * lain.length)];
          cabangTujuanId = tujuan.cabang_id;
        }
      }

      const driverIdx = Math.floor(Math.random() * drivers.length);
      const body = {
        no_resi_list: batch,
        status_baru: 'keluar_cabang',
        driver_user_id: driverIds[driverIdx] || null,
        tipe_tujuan: tipeTujuan,
        cabang_tujuan_id: cabangTujuanId || undefined,
        cabang_nama_manual: cabangTujuanId ? undefined : 'Penerima Langsung',
      };

      batchTotal++;
      try {
        const r = await timed('batch.keluar', () => request('POST', '/transactions/batch-status', body, token));
        if (r.status === 200 && r.data.success) {
          batchOk++;
          // Catat manifest
        } else {
          batchFail++;
        }
      } catch { batchFail++; }
    }
  }
  console.log(`     Batch keluar: ${batchOk} OK / ${batchFail} Fail / ${batchTotal} total`);

  // ─── PHASE C: DRIVER RECEIVE ──────────────────────────────
  console.log('\n[6] PHASE C — Driver process transactions (scan diterima)...');
  let driverOk = 0, driverFail = 0, driverTotal = 0;

  // Driver 1: fetch tugasnya
  const driverTokens = [driver1Token, driver2Token].filter(Boolean);
  for (const dt of driverTokens) {
    try {
      // Get current tasks
      const tasksRes = await timed('driver.getTasks', () =>
        request('GET', '/transactions?tab=current&status=proses_kirim', null, dt)
      );
      if (tasksRes.status === 200 && tasksRes.data?.data?.length > 0) {
        const txList = tasksRes.data.data.map(t => t.no_resi);
        // Batch receive 5 at a time
        for (let i = 0; i < txList.length; i += 5) {
          const batch = txList.slice(i, i + 5);
          driverTotal++;
          try {
            const r = await timed('driver.receive', () =>
              request('POST', '/transactions/batch-status', {
                no_resi_list: batch,
                status_baru: 'diterima',
                catatan: 'Diterima oleh penerima (load test)',
              }, dt)
            );
            if (r.status === 200) driverOk++;
            else driverFail++;
          } catch { driverFail++; }
        }
      }
    } catch { /* driver mungkin tidak punya tugas */ }
  }
  console.log(`     Driver process: ${driverOk} OK / ${driverFail} Fail / ${driverTotal} total`);

  // ─── PHASE D: PARALLEL QUERIES (all cabangs simultaneously) ──
  console.log('\n[7] PHASE D — Parallel queries (list, history, reports, manifests)...');

  async function parallelQuery(label, fn, concurrency = loggedIn) {
    const codes = Object.keys(adminTokens).slice(0, concurrency);
    const start = Date.now();
    const results = await Promise.allSettled(
      codes.map((kode) => timed(label, () => fn(adminTokens[kode], kode)))
    );
    const elapsed = Date.now() - start;
    const ok = results.filter(r => r.status === 'fulfilled' && r.value?.status < 500).length;
    const fail = results.filter(r => r.status === 'rejected' || r.value?.status >= 500).length;
    return { ok, fail, elapsed, total: codes.length };
  }

  // D1: GET /transactions (list default — 40 cabang bersamaan)
  await parallelQuery('q.list', (token) => request('GET', '/transactions?limit=5', null, token));

  // D2: GET /transactions?status=proses_kirim&limit=5
  await parallelQuery('q.filtered', (token) => request('GET', '/transactions?status=proses_kirim&limit=5', null, token));

  // D3: Search by no_resi
  if (allTransactions.length > 0) {
    const sampleResi = allTransactions[Math.floor(Math.random() * allTransactions.length)].no_resi;
    await parallelQuery('q.search', (token) => request('GET', `/transactions?search=${sampleResi}&limit=5`, null, token));
  }

  // D4: Cabang list
  await parallelQuery('q.cabangs', (token) => request('GET', '/cabangs', null, token));

  // D5: Manifests list
  await parallelQuery('q.manifests', (token) => request('GET', '/manifests?limit=5', null, token));

  // D6: Manifests with transactions embedded
  await parallelQuery('q.manifests.embed', (token) => request('GET', '/manifests?limit=5&include=transactions', null, token));

  // D7: Recent contacts
  await parallelQuery('q.contacts', (token, kode) => {
    const cabang = cabangMap[kode];
    const cabangId = cabang?.cabang_id || '';
    return request('GET', `/transactions/recent-contacts?cabang_id=${cabangId}&limit=20`, null, token);
  });

  // ─── PHASE E: SUPER ADMIN QUERIES ─────────────────────────
  console.log('\n[8] PHASE E — Super Admin analytics & reports...');
  const now = new Date();
  const month = now.getMonth() + 1;
  const year = now.getFullYear();

  const saEndpoints = [
    ['sa.summary', () => request('GET', '/analytics/summary', null, saToken)],
    ['sa.traffic', () => request('GET', `/analytics/traffic?start=${year}-${String(month).padStart(2, '0')}-01&end=${year}-${String(month).padStart(2, '0')}-28`, null, saToken)],
    ['sa.perCabang', () => request('GET', `/analytics/per-cabang?month=${month}&year=${year}`, null, saToken)],
    ['sa.wajibSetor', () => request('GET', `/analytics/wajib-setor?month=${month}&year=${year}`, null, saToken)],
    ['sa.routesTop', () => request('GET', `/analytics/routes-top?month=${month}&year=${year}`, null, saToken)],
    ['sa.drivers', () => request('GET', `/analytics/drivers?month=${month}&year=${year}`, null, saToken)],
    ['sa.driverPerf', () => request('GET', `/analytics/driver-performance?month=${month}&year=${year}`, null, saToken)],
    ['sa.manifests', () => request('GET', '/manifests?limit=20&include=transactions', null, saToken)],
    ['sa.manifestStats', () => request('GET', '/manifests/stats/summary', null, saToken)],
    ['sa.transactions', () => request('GET', `/transactions?limit=20&start_date=${year}-${String(month).padStart(2, '0')}-01&end_date=${year}-${String(month).padStart(2, '0')}-28`, null, saToken)],
    ['sa.customersTop', () => request('GET', `/analytics/customers-top?month=${month}&year=${year}`, null, saToken)],
    ['sa.userMe', () => request('GET', '/auth/me', null, saToken)],
  ];

  for (const [label, fn] of saEndpoints) {
    try { await timed(label, fn); } catch {}
  }

  // ─── PHASE F: PAYMENT CONFIRMATION ────────────────────────
  console.log('\n[9] PHASE F — Payment confirmation (COD/Tempo per cabang)...');
  let paymentOk = 0, paymentFail = 0, paymentTotal = 0;

  for (const kode of cabangCodes.slice(0, 20)) { // 20 cabang saja
    const token = adminTokens[kode];
    if (!token) continue;
    try {
      // Get COD/Tempo unpaid
      const r = await timed('payment.fetchCOD', () =>
        request('GET', '/transactions?jenis_pembayaran=cod&status_pembayaran=unpaid&limit=50', null, token)
      );
      if (r.status === 200 && r.data?.data?.length > 0) {
        const ids = r.data.data.map(t => t._id);
        if (ids.length > 0) {
          paymentTotal++;
          try {
            const payR = await timed('payment.massal', () =>
              request('PUT', '/transactions/konfirmasi-pembayaran-massal', { ids: ids.slice(0, 10) }, token)
            );
            if (payR.status === 200) paymentOk++;
            else paymentFail++;
          } catch { paymentFail++; }
        }
      }
    } catch { /* no COD/Tempo for this cabang */ }
  }
  console.log(`     Payment: ${paymentOk} OK / ${paymentFail} Fail / ${paymentTotal} total`);

  // ─── PHASE G: MANIFEST DETAIL ─────────────────────────────
  console.log('\n[10] PHASE G — Manifest detail...');
  try {
    const mList = await timed('manifest.fetchList', () =>
      request('GET', '/manifests?limit=10', null, saToken)
    );
    if (mList.status === 200 && mList.data?.data?.length > 0) {
      const manifests = mList.data.data;
      const detailPromises = manifests.slice(0, 5).map((m) =>
        timed('manifest.detail', () => request('GET', `/manifests/${m._id}`, null, saToken))
      );
      await Promise.allSettled(detailPromises);
    }
  } catch {}

  // ─── PHASE H: CONCURRENCY SPIKE (burst 100 parallel requests) ──
  console.log('\n[11] PHASE H — Concurrency spike (100 requests burst)...');
  const burstPromises = [];
  for (let i = 0; i < 100; i++) {
    const kode = cabangCodes[i % cabangCodes.length];
    const token = adminTokens[kode];
    if (token) {
      burstPromises.push(
        timed('burst.list', () => request('GET', '/transactions?limit=3', null, token))
      );
    }
  }
  await Promise.allSettled(burstPromises);

  // ─── SUMMARY ──────────────────────────────────────────────
  const totalElapsed = ((Date.now() - startAll) / 1000).toFixed(0);
  console.log(`\n═══ SELESAI dalam ${totalElapsed}s ═══`);
  summary();
}

main().catch((e) => {
  console.error('FATAL:', e.message);
  summary();
  process.exit(1);
});
