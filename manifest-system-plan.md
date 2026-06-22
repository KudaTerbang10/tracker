# Manifest System — Implementation Plan

---

## Ringkasan

Setelah admin scan barang keluar dan konfirmasi, sistem auto-generate **Manifest** yang mengelompokkan semua resi dalam satu batch. Driver melihat manifest sebagai grup (bukan per-resi). Work unit dihitung: antar-cabang = 1, antar-penerima = per-resi.

---

## 1. File Changes — Backend (6 files)

### 1a. `backend/models/Manifest.js` — CREATE

Schema baru untuk collection `manifests`:

| Field | Type | Description |
|---|---|---|
| `no_manifest` | String (unique) | `MAN-YYYYMMDD-XXXX` |
| `created_by` | Object | `{user_id, name, cabang_id, cabang_name}` |
| `driver` | Object | `{user_id?, name, phone}` |
| `tujuan` | Object | `{tipe: 'cabang'\|'penerima', cabang_id?, nama}` |
| `asal_cabang_id`, `asal_cabang_name` | ObjectId, String | Cabang asal |
| `resi_list` | Array | `[{no_resi, transaction_id, status: 'terdaftar'\|'selesai'}]` |
| `total_resi` | Number | Jumlah resi |
| `total_berat_kg` | Number | Total berat |
| `total_koli` | Number | Total koli |
| `tipe_manifest` | String | `'antar_cabang'` atau `'antar_penerima'` |
| `work_unit` | Number | `1` (antar_cabang) atau `n` (antar_penerima) |
| `status` | String | `'dibuat'` → `'dalam_perjalanan'` → `'selesai'` |
| `completed_at` | Date | Timestamp selesai |

Indexes: `no_manifest`, `{driver.user_id, status}`, `asal_cabang_id+createdAt`, `status`

### 1b. `backend/utils/manifestGenerator.js` — CREATE

Generate `MAN-{YYYYMMDD}-{XXXX}` via model `Counter` (key: `manifest_{YYYYMMDD}`), pattern yang sudah ada dari resi generator.

### 1c. `backend/routes/transaction.js` — MODIFY

Di akhir handler `POST /batch-status`, setelah semua transaksi berhasil di-`bulkWrite`:

```javascript
// — AUTO-GENERATE MANIFEST —
let manifest = null;
if (status_baru === 'keluar_cabang' && berhasilCount > 0) {
  const generateNoManifest = require('../utils/manifestGenerator');
  const no_manifest = await generateNoManifest();

  const tipeManifest = tipe_tujuan === 'cabang' ? 'antar_cabang' : 'antar_penerima';
  const workUnit = tipe_tujuan === 'cabang' ? 1 : berhasilCount;

  const resiList = [];
  let totalBerat = 0, totalKoli = 0;
  for (const [txIdStr, tx] of validTxMap) {
    resiList.push({ no_resi: tx.no_resi, transaction_id: tx._id, status: 'terdaftar' });
    totalBerat += tx.paket?.berat_kg || 0;
    totalKoli += tx.paket?.jumlah_koli || 0;
  }

  const Manifest = require('../models/Manifest');
  manifest = await Manifest.create({ /* semua field */ });

  // Update no_manifest di setiap transaction
  await Transaction.updateMany(
    { _id: { $in: validIds } },
    { $set: { no_manifest } }
  );
}
```

Response ditambah: `manifest: { _id, no_manifest, total_resi, tipe_manifest, work_unit }`

### 1d. `backend/routes/manifest.js` — CREATE

| Method | Path | Deskripsi |
|--------|------|-----------|
| `GET` | `/api/manifests` | List manifests. Admin_cabang → filter by `created_by.user_id`. Driver → filter by `driver.user_id`. Query params: `status`, `page`, `limit` |
| `GET` | `/api/manifests/:id` | Detail manifest + populate transactions per resi |
| `GET` | `/api/manifests/stats/summary` | Aggregate `work_unit` per status (untuk summary driver) |

### 1e. `backend/server.js` — MODIFY

Tambah: `app.use('/api/manifests', manifestRoutes);`

### 1f. `backend/models/Counter.js` — No Change

---

## 2. File Changes — Flutter (14 files)

### 2a. `lib/data/models/manifest.dart` — CREATE

```dart
class ManifestResiItem {
  String noResi, transactionId, status;
  Transaction? transaction; // populated di detail
}

class Manifest {
  String id, noManifest;
  Map createdBy, driver, tujuan;
  String asalCabangId, asalCabangName;
  List<ManifestResiItem> resiList;
  int totalResi, totalKoli, workUnit;
  double totalBeratKg;
  String tipeManifest, status;
  DateTime? completedAt, createdAt, updatedAt;

  bool get isAntarCabang => tipeManifest == 'antar_cabang';
  String get statusLabel;
  String get driverName;
  String get tujuanNama;
}
```

### 2b. `lib/core/constants/api_constants.dart` — MODIFY

Tambah `static const String manifests = '/manifests';`

### 2c. `lib/features/manifest/providers/manifest_provider.dart` — CREATE

Providers:
- `manifestListProvider` — `FutureProvider.autoDispose.family<List<Manifest>, ManifestFilter>`
- `manifestDetailProvider` — `FutureProvider.autoDispose.family<Manifest, String>`
- `manifestStatsProvider` — `FutureProvider.autoDispose<Map<String, dynamic>>`
- `driverManifestProvider` — fetches manifests for current driver

### 2d. `lib/features/manifest/screens/manifest_list_screen.dart` — CREATE

- AppBar: "Daftar Manifest"
- FilterChips: Semua | Dibuat | Dalam Perjalanan | Selesai
- ListView of cards, each = **ExpansionTile**:
  - Header: `no_manifest` (monospace, bold), tipe badge, work unit badge
  - Expanded: list resi (no_resi + pengirim→penerima)
- Tap card → navigasi ke detail

### 2e. `lib/features/manifest/screens/manifest_detail_screen.dart` — CREATE

Layout:
1. Header card: `no_manifest` + status badge
2. Info card: asal → tujuan, tipe, work unit
3. Driver card: nama + kontak
4. Summary: total resi, berat, koli
5. **Daftar Resi**: ListView, setiap item = pengirim → penerima, berat, koli
6. **Tombol Cetak PDF**: FloatingActionButton atau di AppBar

### 2f. Cetak PDF di `manifest_detail_screen.dart`

Generate PDF dengan `pdf` + `printing`:
- Judul: "MANIFEST PENGIRIMAN"
- Meta: no_manifest, tanggal, driver, asal, tujuan
- Tabel: No, No Resi, Pengirim, Penerima, Berat, Koli
- Footer: total + garis tanda tangan

### 2g. `lib/features/scan_batch/screens/manifest_result_sheet.dart` — CREATE

Bottom sheet sukses:
```
┌─────────────────────────────┐
│  ✅ Berhasil Dibuat!         │
│                             │
│  MAN-20250611-0001          │
│  5 Paket                    │
│  Driver: Bambang            │
│  Tujuan: Cabang Bandung     │
│  Work Unit: 1               │
│                             │
│  [Lihat Detail Manifest]    │
│  [Kembali ke Scan]          │
└─────────────────────────────┘
```

### 2h. `lib/features/scan_batch/screens/scan_keluar_screen.dart` — MODIFY

Di `_confirm()`:
- Setelah `batchUpdateStatus` sukses, baca `manifest` dari response
- Tampilkan `ManifestResultSheet`
- Opsi "Lihat Detail" → `context.push('/dashboard/manifest/${manifestId}')`
- Opsi "Kembali" → `notifier.clear()`

### 2i. `lib/features/scan_batch/providers/scan_batch_provider.dart` — MODIFY

Tambah field `Map<String, dynamic>? manifestResult` di `ScanKeluarState`, setter `setManifestResult()` di `ScanKeluarNotifier`.

### 2j. `lib/features/driver/screens/driver_tab_screen.dart` — MODIFY (MAJOR)

**Tab "Perlu Dikirim" — Manifest Primary View:**

```dart
final driverManifestProvider = FutureProvider.autoDispose<List<Manifest>>((ref) async {
  final response = await ApiService().get(ApiConstants.manifests, queryParameters: {
    'status': 'dibuat,dalam_perjalanan', // belum selesai
  });
  return (response.data['data'] as List).map((e) => Manifest.fromJson(e)).toList();
});
```

Setiap card manifest → **ExpansionTile**:
- Header: `Icons.description_rounded` + `no_manifest` (monospace) + tipe badge
- Subtitle: tujuan + driver + work unit
- Expanded tile: ListView of resi, setiap item = no_resi + pengirim→penerima
- Tap → `_showManifestDetail(manifest)` — bisa panggil detail screen atau bottom sheet

**Summary bar** di atas list:
```
"Total: 3 manifest · 12 resi · 5 work unit"
```

**Tab "Riwayat"**: tetap sama seperti sekarang.

### 2k. `lib/features/driver/providers/route_provider.dart` — MODIFY

Route optimization perlu ambil transaksi dari manifest:
- Fetch manifests → extract semua `transaction_id` dari `resi_list` → fetch transaksi
- Atau: gunakan `manifestDetailProvider` untuk expand transaksi
- Group stops: tetap berdasarkan tipe tujuan (cabang/penerima)

Alternatif simpel: Tab "Perlu Dikirim" tetap pakai `kirimProvider` untuk data map/rute, tapi tampilan utamanya adalah manifest cards. Map bisa tetap muncul untuk visualisasi rute.

### 2l. `lib/router/app_router.dart` — MODIFY

Tambah:
- `/dashboard/manifests` → `ManifestListScreen` (untuk admin)
- `/dashboard/manifest/:id` → `ManifestDetailScreen`

### 2m. `lib/features/dashboard/screens/dashboard_screen.dart` — MODIFY

Tambah menu item untuk `admin_cabang`:
```dart
DashboardMenuItem(
  icon: Icons.description_rounded,
  label: 'Daftar Manifest',
  route: '/dashboard/manifests',
  roles: ['admin_cabang', 'super_admin'],
)
```

---

## 3. Ringkasan Alur

### Admin → Scan Keluar → Manifest

```
scan barcode → pilih driver + tujuan → konfirmasi
  → POST /batch-status
    → Transaction.bulkWrite (update transaksi)
    → Manifest.create (auto-generate)
    → response: { berhasil, manifest: {no_manifest, ...} }
  → Flutter: ManifestResultSheet
  → [Lihat Detail] → ManifestDetailScreen
```

### Driver → Lihat Manifest

```
buka tab "Perlu Dikirim"
  → GET /manifests?status=dibuat,dalam_perjalanan
  → tampilkan summary bar + list manifest cards
  → expand card → lihat daftar resi
  → tap card → ManifestDetailScreen (dengan tombol cetak PDF)
```

---

## 4. Work Unit Logic

| Tipe Manifest | Contoh | Work Unit |
|---|---|---|
| `antar_cabang` | 20 resi ke Cabang Bandung | **1** |
| `antar_penerima` | 5 resi ke 5 penerima | **5** |

Satu batch scan hanya bisa satu tipe tujuan (FilterChip di UI), jadi tidak ada campur aduk.

---

## 5. Verifikasi Checklist

- [ ] `POST /batch-status` → response mengandung `manifest` object
- [ ] Collection `manifests` di MongoDB terisi
- [ ] Admin bisa lihat daftar manifest + filter by status
- [ ] Admin bisa lihat detail manifest + daftar resi
- [ ] Admin bisa cetak manifest PDF
- [ ] Setelah scan keluar, muncul bottom sheet manifest
- [ ] Driver lihat manifest di tab "Perlu Dikirim"
- [ ] Driver bisa expand card untuk lihat resi
- [ ] Summary bar muncul dengan total manifest + resi + work unit
- [ ] Work unit antar_cabang = 1, antar_penerima = per-resi
