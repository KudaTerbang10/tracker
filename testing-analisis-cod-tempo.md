# Analisis Testing Transaksi COD & Tempo

---

## 1. Testing Pembuatan Transaksi

| No | Skenario | Role | Input | Hasil Diharapkan | Catatan |
|---|---|---|---|---|---|
| 1.1 | Buat transaksi COD normal | admin_cabang | jenis_pembayaran=cod, biaya_kirim=50000, pengirim+penerima+papaket lengkap | status_pembayaran=unpaid, status_saat_ini=diterima_cabang, resi tercetak dengan badge COD | Biaya kirim wajib > 0 |
| 1.2 | Buat transaksi COD tanpa biaya kirim | admin_cabang | jenis_pembayaran=cod, biaya_kirim=0 / kosong | **Error:** snackbar "Biaya kirim wajib diisi untuk pembayaran COD/Tempo" | Validasi di create_transaction_screen.dart |
| 1.3 | Buat transaksi Tempo normal | admin_cabang | jenis_pembayaran=tempo, tempo_hari=30, biaya_kirim=75000 | status_pembayaran=unpaid, tempo_hari=30 (default 14 jika tidak diisi) | Field `tempo_hari` opsional |
| 1.4 | Buat transaksi Tempo tanpa tempo_hari | admin_cabang | jenis_pembayaran=tempo, tanpa tempo_hari | status_pembayaran=unpaid, tempo_hari=14 (default backend) | Default di model Transaction.js |
| 1.5 | Buat transaksi COD oleh super_admin | super_admin | jenis_pembayaran=cod | status_pembayaran=unpaid, created_by.role=super_admin | Super admin bisa buat dari cabang mana pun |
| 1.6 | Buat transaksi COD dengan biaya kirim = 1000000 | admin_cabang | biaya_kirim=1000000 | Tersimpan dengan benar 1.000.000 | Uji batas atas |
| 1.7 | Buat transaksi Tempo, lalu buat lagi COD di cabang yang sama | admin_cabang | Dua transaksi berbeda | Masing-masing independen, badge tab terpisah di manajemen pembayaran | |

---

## 2. Testing Scan Flow — Transaksi COD Sukses

| No | Skenario | Role | Input | Hasil Diharapkan | Catatan |
|---|---|---|---|---|---|
| 2.1 | Scan DATANG di cabang A | admin_cabang (cabang A) | no_resi COD yang baru dibuat | status_saat_ini=diterima_cabang, current_cabang_id=cabang A | Transaksi muncul di daftar transaksi cabang A |
| 2.2 | Scan KELUAR ke penerima dari cabang A | admin_cabang (cabang A) | driver=Hendra, tipe_tujuan=penerima | status_saat_ini=keluar_cabang, cod_cabang_id=cabang A, manifest antar_penerima | cod_cabang_id di-set di sini — menandai last mile |
| 2.3 | Scan DITERIMA oleh driver Hendra | driver (Hendra) | resi, nama_penerima="Budi", verifikasi GPS | status_saat_ini=diterima, nama_penerima_akhir=Budi | Verifikasi GPS wajib, bisa override |
| 2.4 | Scan DITERIMA oleh admin_cabang | admin_cabang (cabang A) | resi, nama_penerima="Budi" | status_saat_ini=diterima | Admin cabang juga bisa scan diterima |
| 2.5 | Driver bukan penugasan mencoba scan DITERIMA | driver (bukan Hendra) | resi | **Error:** akses ditolak | driver_user_id harus match |
| 2.6 | Konfirmasi pembayaran COD setelah diterima | admin_cabang (cabang A) | tombol "Konfirmasi Lunas" di manajemen pembayaran | status_pembayaran=paid, pembayaran_dikonfirmasi_oleh terisi, card pindah ke bawah (lunas) | Hanya admin last mile |

---

## 3. Testing Scan Flow — Multi-Cabang (Antar Cabang + Last Mile COD)

| No | Skenario | Role | Input | Hasil Diharapkan | Catatan |
|---|---|---|---|---|---|
| 3.1 | Cabang A scan KELUAR ke cabang B | admin_cabang (A) | driver=Andi, tipe_tujuan=cabang, cabang_tujuan=B | status=keluar_cabang, cod_cabang_id belum di-set, manifest antar_cabang | COD belum diset karena belum last mile |
| 3.2 | Cabang B scan DATANG | admin_cabang (B) | no_resi/manifest | status=diterima_cabang, current_cabang_id=B | |
| 3.3 | Cabang B scan KELUAR ke penerima | admin_cabang (B) | driver=Budi, tipe_tujuan=penerima | status=keluar_cabang, cod_cabang_id=B (last mile) | Baru sekarang cod_cabang_id di-set |
| 3.4 | Driver Budi scan DITERIMA | driver (Budi) | resi, nama_penerima | status=diterima | |
| 3.5 | Konfirmasi pembayaran oleh cabang B | admin_cabang (B) | Konfirmasi Lunas | Berhasil — ini last mile yang sah | Cabang A tidak bisa konfirmasi |

---

## 4. Testing Gagal Kirim (COD)

| No | Skenario | Role | Input | Hasil Diharapkan | Catatan |
|---|---|---|---|---|---|
| 4.1 | Laporkan gagal kirim dari daftar transaksi | admin_cabang (cabang last mile) | pilih resi COD, "Gagal Kirim", catatan="Alamat tidak ditemukan" | status_saat_ini=gagal_kirim, jenis_masalah=gagal_kirim, tujuan_selanjutnya=created_by.cabang_id | Auto set retur ke cabang asal |
| 4.2 | Laporkan gagal kirim dari detail manifest | admin_cabang (last mile) | sama seperti 4.1 via manifest | Hasil sama | UI path berbeda, API sama |
| 4.3 | Laporkan gagal kirim tapi status sudah diterima | admin_cabang | transaksi status=diterima | **Error:** tidak bisa laporkan | Backend tolak |
| 4.4 | Laporkan manual dari transaksi bermasalah (resi dari cabang lain) | admin_cabang (cabang mana pun) | input nomor resi manual lalu cari lalu laporkan | Berhasil (via problematic_transactions_screen) | Bisa cari resi dari cabang mana pun |
| 4.5 | Admin cabang asal konfirmasi pembayaran COD gagal kirim | admin_cabang (asal) | Konfirmasi Lunas di manajemen pembayaran | Berhasil — backend izinkan admin cabang asal untuk konfirmasi retur | Syarat: jenis_masalah=gagal_kirim |
| 4.6 | Cetak Resi Retur untuk gagal kirim | admin_cabang | Tombol cetak di problematic_transactions_screen | Label retur dengan pengirim-penerima terbalik, badge COD | |
| 4.7 | Anulir gagal kirim | admin_cabang (pelapor) / super_admin | Tombol "Anulir Gagal Kirim" | status kembali ke diterima_cabang, jenis_masalah null | |
| 4.8 | Anulir gagal kirim oleh admin cabang lain | admin_cabang (bukan pelapor) | Tombol "Anulir Gagal Kirim" | **Error:** hanya pelapor atau super_admin | |

---

## 5. Testing Barang Hilang (COD)

| No | Skenario | Role | Input | Hasil Diharapkan | Catatan |
|---|---|---|---|---|---|
| 5.1 | Laporkan hilang | admin_cabang | pilih resi, "Barang Hilang", catatan | status_saat_ini=hilang, jenis_masalah=hilang | Muncul di tab bermasalah |
| 5.2 | Super admin tandai selesai | super_admin | "Tandai Selesai" | status_saat_ini=kasus_selesai, diselesaikan_oleh terisi | Hanya super_admin |
| 5.3 | Admin cabang coba tandai selesai | admin_cabang | "Tandai Selesai" | **Error / tombol tidak muncul** | RBAC super_admin only |
| 5.4 | Batalkan hilang (barang ditemukan) | admin_cabang (pelapor) | "Barang Ditemukan" | status kembali ke diterima_cabang | Hanya pelapor atau super_admin |
| 5.5 | Batalkan kasus selesai | super_admin | "Batalkan Kasus Selesai" | status kembali ke diterima_cabang | Revert dari kasus_selesai |
| 5.6 | Konfirmasi pembayaran COD barang hilang | admin_cabang (last mile) | Konfirmasi Lunas | **Error:** tidak bisa (bukan last mile / bukan gagal_kirim) | Backend tolak |

---

## 6. Testing Konfirmasi Pembayaran

| No | Skenario | Role | Input | Hasil Diharapkan | Catatan |
|---|---|---|---|---|---|
| 6.1 | Konfirmasi COD di last mile | admin_cabang (last mile) | Konfirmasi Lunas | status_pembayaran=paid, badge berubah "Lunas" | Syarat: cod_cabang_id = user.cabang_id |
| 6.2 | Konfirmasi COD oleh cabang bukan last mile | admin_cabang (cabang lain) | Konfirmasi Lunas | **Error:** bukan last mile | Backend tolak |
| 6.3 | Konfirmasi COD oleh super_admin | super_admin | Konfirmasi Lunas | **Error:** super_admin tidak bisa konfirmasi COD | Backend khusus tolak super_admin untuk COD |
| 6.4 | Konfirmasi Tempo oleh admin cabang asal | admin_cabang (asal) | Konfirmasi Lunas | Berhasil | Syarat: created_by.cabang_id = user.cabang_id |
| 6.5 | Konfirmasi Tempo oleh admin cabang lain | admin_cabang (cabang lain) | Konfirmasi Lunas | **Error:** bukan cabang asal | |
| 6.6 | Konfirmasi Tempo oleh super_admin | super_admin | Konfirmasi Lunas | Berhasil | Super admin bisa konfirmasi semua Tempo |
| 6.7 | Konfirmasi ulang transaksi yang sudah lunas | admin_cabang | Konfirmasi Lunas lagi | **Error:** status_pembayaran sudah paid | Backend tolak, tombol juga tidak muncul di UI |
| 6.8 | Batalkan konfirmasi | — | — | Tidak ada endpoint | Tidak bisa membatalkan konfirmasi |

---

## 7. Testing Manajemen Pembayaran (Dashboard)

| No | Skenario | Role | Hasil Diharapkan | Catatan |
|---|---|---|---|---|
| 7.1 | Lihat tab COD bulan ini | admin_cabang | Semua transaksi COD di bulan ini, unpaid di atas, paid di bawah | Badge "Lunas" / "Belum Lunas" + badge "COD" |
| 7.2 | Lihat tab Tempo bulan ini | admin_cabang / super_admin | Semua transaksi Tempo di bulan ini, unpaid di atas | Badge jatuh tempo: "Jatuh Tempo X hari lagi" / "Jatuh Tempo Xh lalu" |
| 7.3 | Ganti bulan via picker | admin_cabang | Data reload sesuai bulan terpilih | Month picker: 3 kolom x 4 baris |
| 7.4 | Search no_resi di tab COD | admin_cabang | Filter client-side, yang match saja | Search by no_resi, pengirim, penerima |
| 7.5 | Pull-to-refresh | admin_cabang | Data reload dari server | |
| 7.6 | Super admin tidak lihat tab COD | super_admin | Tab COD tidak muncul | hasCOD = role == 'admin_cabang' |
| 7.7 | Driver tidak bisa akses halaman ini | driver | Tidak bisa navigasi ke /dashboard/pembayaran | |

---

## 8. Testing Laporan

| No | Skenario | Role | Input | Hasil Diharapkan | Catatan |
|---|---|---|---|---|---|
| 8.1 | Cetak Laporan COD bulan ini | admin_cabang | Pilih bulan, "Cetak Laporan COD" | PDF dengan tabel: No, Resi, Pengirim, Penerima, Nominal, Status | Ada summary: total resi, total nominal, jumlah lunas |
| 8.2 | Cetak Laporan COD bulan tanpa data | admin_cabang | Pilih bulan kosong | Snackbar: "Tidak ada data COD untuk [bulan] [tahun]" | |
| 8.3 | Cetak Laporan Tempo | admin_cabang / super_admin | "Cetak Laporan Tempo" | PDF "LAPORAN TEMPO" + periode + cabang | |
| 8.4 | Cetak Laporan Gagal Kirim | admin_cabang | Dari problematic screen | PDF data gagal_kirim | |
| 8.5 | Cetak Laporan Barang Hilang | admin_cabang | Dari problematic screen | PDF data hilang | |
| 8.6 | Cetak Label Barcode COD | admin_cabang | Tombol print di card transaksi / detail | Label dengan badge COD | Bisa cetak dari berbagai screen |

---

## 9. Testing RBAC & Edge Cases

| No | Skenario | Role | Hasil Diharapkan | Catatan |
|---|---|---|---|---|
| 9.1 | COD — admin cabang hanya lihat transaksi di cod_cabang_id miliknya | admin_cabang (A) | Hanya lihat transaksi yg last mile-nya A, atau gagal_kirim dari A | Filter di backend GET /transactions |
| 9.2 | Tempo — admin cabang hanya lihat transaksi dari created_by.cabang_id miliknya | admin_cabang (A) | Hanya lihat Tempo yang dibuat di cabang A | |
| 9.3 | Transaksi COD dengan masalah hilang tidak muncul di manajemen pembayaran | admin_cabang | Transaksi hilang exclude dari query COD | Backend filter: jenis_masalah != hilang |
| 9.4 | Transaksi Tempo dengan masalah hilang/gagal_kirim tidak muncul di manajemen pembayaran | admin_cabang | Exclude dari query Tempo | Backend filter: jenis_masalah nin [hilang, gagal_kirim] |
| 9.5 | Konfirmasi pembayaran offline (tanpa koneksi) | admin_cabang | Error — snackbar gagal | Tidak ada offline support |
| 9.6 | Cetak laporan PDF dengan 50+ transaksi | admin_cabang | Paginasi otomatis setiap 25 baris | Payment_report_printer.dart |
| 9.7 | Transaksi COD diterima -> otomatis muncul di tab COD | admin_cabang (last mile) | Setelah diterima, muncul di manajemen pembayaran (unpaid) | cod_cabang_id sudah di-set saat scan keluar ke penerima |

---

## 10. Testing Alur Lengkap End-to-End

| No | Flow | Role | Langkah | Verifikasi |
|---|---|---|---|---|
| 10.1 | COD Sukses | admin_cabang -> driver -> admin_cabang | 1. Buat transaksi COD di cabang A<br>2. Scan datang di A<br>3. Scan keluar ke penerima (driver Hendra)<br>4. Scan diterima oleh Hendra<br>5. Konfirmasi pembayaran di manajemen pembayaran | status_pembayaran=paid, muncul di tab COD sebagai "Lunas" |
| 10.2 | COD Gagal Kirim -> Retur | admin_cabang -> admin_cabang (asal) | 1. Buat COD di cabang A<br>2. Scan datang A<br>3. Scan keluar ke cabang B<br>4. Scan datang B<br>5. Scan keluar B ke penerima<br>6. Laporkan gagal kirim<br>7. Admin A konfirmasi pembayaran | status=gagal_kirim, jenis_masalah=gagal_kirim, admin A bisa konfirmasi |
| 10.3 | COD Hilang -> Selesai | admin_cabang -> super_admin | 1. Buat COD di cabang A<br>2. Scan datang A<br>3. Laporkan hilang<br>4. Super admin tandai selesai | status=kasus_selesai, tidak muncul di manajemen pembayaran |
| 10.4 | Tempo — Lunas di Cabang Asal | admin_cabang (asal) | 1. Buat Tempo di cabang A<br>2. Konfirmasi pembayaran oleh admin A | status_pembayaran=paid, muncul sebagai "Lunas" |
| 10.5 | Tempo — Lunas oleh Super Admin | super_admin | 1. Super admin konfirmasi Tempo dari cabang mana pun | Berhasil (super_admin bisa semua) |
| 10.6 | COD Multi-Cabang + Konfirmasi | admin_cabang (A, B, C) | 1. Buat di A<br>2. A->B (antar cabang)<br>3. B->C (antar cabang)<br>4. C->penerima (last mile)<br>5. Konfirmasi oleh C | cod_cabang_id=C, hanya admin C yang bisa konfirmasi |
