import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/widgets/barcode_widget.dart';
import '../../../shared/widgets/location_picker.dart';
import '../../../shared/utils/label_printer.dart';
import '../../../shared/utils/sound_player.dart';
import '../../../shared/utils/ongkir_service.dart';
import '../../auth/providers/auth_provider.dart';

class CreateTransactionScreen extends ConsumerStatefulWidget {
  const CreateTransactionScreen({super.key});
  @override
  ConsumerState<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState
    extends ConsumerState<CreateTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _pengirimNameC = TextEditingController();
  final _pengirimPhoneC = TextEditingController();
  final _pengirimAddrC = TextEditingController();
  final _penerimaNameC = TextEditingController();
  final _penerimaPhoneC = TextEditingController();
  final _penerimaAddrC = TextEditingController();
  final _penerimaKecC = TextEditingController();
  final _beratC = TextEditingController();
  final _koliC = TextEditingController(text: '1');
  final _biayaC = TextEditingController();

  bool _submitting = false;
  Transaction? _createdTransaction;
  String? _kotaTujuan;
  double? _penerimaLat;
  double? _penerimaLng;
  OngkirResult? _ongkirResult;
  bool _originFound = true;
  int _autocompleteResetKey = 0;
  bool _isFormattingAddr = false;
  bool _isFormattingPhone = false;
  String _jenisPembayaran = 'cash';
  double _tempoHari = 14;

  List<Map<String, dynamic>> _recentPenerima = [];
  List<Map<String, dynamic>> _recentPengirim = [];
  bool _recentLoaded = false;
  DateTime? _recentOldestDate;

  String? _originApiKota() {
    final user = ref.read(authProvider).user;
    final cabangKota = user?.lokasi?['kota'] as String?;
    return OngkirService.cabangToKota(cabangKota);
  }

  void _calcOngkir() {
    final asal = _originApiKota();
    final tujuan = _kotaTujuan;
    final beratText = _beratC.text.trim();
    if (asal == null) {
      setState(() {
        _originFound = false;
        _ongkirResult = null;
      });
      return;
    }
    if (tujuan == null || tujuan.isEmpty || beratText.isEmpty) {
      setState(() {
        _ongkirResult = null;
      });
      return;
    }
    final berat = double.tryParse(beratText);
    if (berat == null || berat <= 0) {
      setState(() {
        _ongkirResult = null;
      });
      return;
    }
    final result = OngkirService.hitung(asal, tujuan, berat);
    setState(() {
      _originFound = true;
      _ongkirResult = result;
      if (result != null) _biayaC.text = result.total.toString();
    });
  }

  Future<void> _loadRecentContacts() async {
    if (_recentLoaded) return;
    try {
      final user = ref.read(authProvider).user;
      final cabangId = user?.cabangId;
      if (cabangId == null) return;

      final repo = ref.read(transactionRepositoryProvider);
      final result = await repo.getRecentContacts(cabangId);
      setState(() {
        _recentPenerima = List<Map<String, dynamic>>.from(
          result['penerima'] ?? [],
        );
        _recentPengirim = List<Map<String, dynamic>>.from(
          result['pengirim'] ?? [],
        );
        _recentLoaded = true;
        if (result['oldestDate'] != null) {
          _recentOldestDate = DateTime.tryParse(
            result['oldestDate'].toString(),
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _showRecentPicker({
    required String title,
    required String type,
    required void Function(Map<String, dynamic>) onSelected,
  }) async {
    await _loadRecentContacts();
    if (!mounted) return;

    final items = type == 'penerima' ? _recentPenerima : _recentPengirim;
    final searchC = TextEditingController();

    // Hitung jumlah bulan berdasarkan tanggal tertua
    int? monthRange;
    if (_recentOldestDate != null) {
      final now = DateTime.now();
      monthRange =
          ((now.year - _recentOldestDate!.year) * 12 +
                  now.month -
                  _recentOldestDate!.month)
              .abs();
      if (monthRange < 1) monthRange = 1;
    }
    final monthLabel = monthRange != null
        ? ' dalam $monthRange bulan terakhir'
        : '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final q = searchC.text.toLowerCase();
            final filtered = q.isEmpty
                ? items
                : items.where((item) {
                    final name = (item['name'] as String? ?? '').toLowerCase();
                    final phone = (item['phone'] as String? ?? '')
                        .toLowerCase();
                    return name.contains(q) || phone.contains(q);
                  }).toList();

            final screenWidth = MediaQuery.of(context).size.width;
            final dialogWidth = screenWidth * 0.3;

            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Riwayat Data ${type == 'penerima' ? 'Penerima' : 'Pengirim'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (monthRange != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Text(
                        'Dalam $monthRange Bulan Terakhir',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              content: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchC,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau telepon...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchC.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchC.clear();
                                  setDialogState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Tidak ada data',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final item = filtered[i];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.primary
                                        .withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.person,
                                      size: 16,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  title: Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        item['phone'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '${item['count'] ?? 0}x Transaksi',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    onSelected(item);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _beratC.addListener(_calcOngkir);
    _pengirimNameC.addListener(_formatPengirimName);
    _penerimaNameC.addListener(_formatPenerimaName);
    _pengirimPhoneC.addListener(_formatPengirimPhone);
    _penerimaPhoneC.addListener(_formatPenerimaPhone);
    _penerimaKecC.addListener(_formatPenerimaKec);
  }

  void _formatPenerimaKec() {
    if (_isFormattingAddr) return;
    _isFormattingAddr = true;
    final text = _penerimaKecC.text;
    // Split kata, kapital huruf pertama tiap kata
    final formatted = text
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        })
        .join(' ');
    if (formatted != text) {
      _penerimaKecC.text = formatted;
      _penerimaKecC.selection = TextSelection.collapsed(
        offset: formatted.length,
      );
    }
    _isFormattingAddr = false;
  }

  void _formatPengirimPhone() {
    if (_isFormattingPhone) return;
    _isFormattingPhone = true;
    final formatted = _formatPhoneDisplay(_pengirimPhoneC.text);
    if (formatted != _pengirimPhoneC.text) {
      _pengirimPhoneC.text = formatted;
      _pengirimPhoneC.selection = TextSelection.collapsed(
        offset: formatted.length,
      );
    }
    _isFormattingPhone = false;
  }

  void _formatPenerimaPhone() {
    if (_isFormattingPhone) return;
    _isFormattingPhone = true;
    final formatted = _formatPhoneDisplay(_penerimaPhoneC.text);
    if (formatted != _penerimaPhoneC.text) {
      _penerimaPhoneC.text = formatted;
      _penerimaPhoneC.selection = TextSelection.collapsed(
        offset: formatted.length,
      );
    }
    _isFormattingPhone = false;
  }

  static String _formatPhoneDisplay(String text) {
    // Hanya ambil digit
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    // Format strip tiap 4 digit hanya untuk nomor yg diawali 08 (nomor HP)
    if (digits.startsWith('08')) {
      final buf = StringBuffer();
      for (int i = 0; i < digits.length; i++) {
        if (i > 0 && i % 4 == 0) buf.write('-');
        buf.write(digits[i]);
      }
      return buf.toString();
    }
    // Nomor non-HP (kantor/rumah) — biarkan apa adanya
    return digits;
  }

  void _formatPengirimName() {
    if (_isFormattingAddr) return;
    _isFormattingAddr = true;
    final formatted = _formatAddress(_pengirimNameC.text);
    if (formatted != _pengirimNameC.text) {
      _pengirimNameC.text = formatted;
      _pengirimNameC.selection = TextSelection.collapsed(
        offset: formatted.length,
      );
    }
    _isFormattingAddr = false;
  }

  void _formatPenerimaName() {
    if (_isFormattingAddr) return;
    _isFormattingAddr = true;
    final formatted = _formatAddress(_penerimaNameC.text);
    if (formatted != _penerimaNameC.text) {
      _penerimaNameC.text = formatted;
      _penerimaNameC.selection = TextSelection.collapsed(
        offset: formatted.length,
      );
    }
    _isFormattingAddr = false;
  }

  static String _formatAddress(String text) {
    final words = text.split(' ');
    final formatted = words
        .map((w) {
          if (w.isEmpty) return w;
          final lower = w.toLowerCase();
          // RT / RW / RT. / RW. sebagai kata utuh (2 huruf, optional titik) -> Rt / Rw
          if (RegExp(r'^(rt|rw)\.?$').hasMatch(lower)) {
            return lower[0].toUpperCase() + lower[1];
          }
          final match = RegExp(
            r'^(rt|rw)\.?(\d+)$',
            caseSensitive: false,
          ).firstMatch(w);
          if (match != null) {
            // rt001 / rw05 / rt.001 -> Rt001 / Rw05 (huruf awal kapital, angka tetap)
            return '${match.group(1)![0].toUpperCase()}${match.group(2)}';
          }
          // biarkan ALL UPPERCASE (PT, CV, dll), title-case-kan sisanya
          if (!w.contains(RegExp(r'[a-z]'))) return w;
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        })
        .join(' ');
    return formatted;
  }

  @override
  void dispose() {
    _beratC.removeListener(_calcOngkir);
    _pengirimNameC.removeListener(_formatPengirimName);
    _penerimaNameC.removeListener(_formatPenerimaName);
    _pengirimPhoneC.removeListener(_formatPengirimPhone);
    _penerimaPhoneC.removeListener(_formatPenerimaPhone);
    _penerimaKecC.removeListener(_formatPenerimaKec);
    _pengirimNameC.dispose();
    _pengirimPhoneC.dispose();
    _pengirimAddrC.dispose();
    _penerimaNameC.dispose();
    _penerimaPhoneC.dispose();
    _penerimaAddrC.dispose();
    _penerimaKecC.dispose();
    _beratC.dispose();
    _koliC.dispose();
    _biayaC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCreated = _createdTransaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(hasCreated ? 'Transaksi Berhasil' : 'Transaksi Baru'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: hasCreated
          ? _buildSuccess()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Penerima Card
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _sectionTitle(
                                    'DATA PENERIMA',
                                    Icons.person_pin_rounded,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.history_rounded,
                                    size: 20,
                                    color: Colors.indigo,
                                  ),
                                  tooltip: 'Riwayat Penerima',
                                  onPressed: () {
                                    _showRecentPicker(
                                      title: 'Riwayat Penerima',
                                      type: 'penerima',
                                      onSelected: (item) {
                                        setState(() {
                                          _penerimaNameC.text = _formatAddress(
                                            item['name'] ?? '',
                                          );
                                          _penerimaPhoneC.text =
                                              _formatPhoneDisplay(
                                                item['phone'] ?? '',
                                              );
                                          _penerimaAddrC.text = _formatAddress(
                                            item['address'] ?? '',
                                          );
                                          _penerimaKecC.text = _formatAddress(
                                            item['kecamatan'] ?? '',
                                          );
                                          _kotaTujuan =
                                              (item['kota'] as String?)
                                                      ?.isNotEmpty ==
                                                  true
                                              ? item['kota']
                                              : null;
                                          // Set koordinat dari lokasi_penerima
                                          final lokasi =
                                              item['lokasi_penerima']
                                                  as Map<String, dynamic>?;
                                          if (lokasi != null &&
                                              lokasi['coordinates'] != null) {
                                            final coords =
                                                lokasi['coordinates'] as List;
                                            if (coords.length >= 2) {
                                              _penerimaLng = (coords[0] as num?)
                                                  ?.toDouble();
                                              _penerimaLat = (coords[1] as num?)
                                                  ?.toDouble();
                                            }
                                          } else {
                                            _penerimaLat = null;
                                            _penerimaLng = null;
                                          }
                                          _autocompleteResetKey++;
                                        });
                                        _calcOngkir();
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _penerimaNameC,
                              decoration: const InputDecoration(
                                labelText: 'Nama Penerima *',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (v) =>
                                  (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _penerimaPhoneC,
                              decoration: const InputDecoration(
                                labelText: 'Kontak Penerima *',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) =>
                                  (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _penerimaAddrC,
                              decoration: const InputDecoration(
                                labelText: 'Alamat Lengkap Penerima *',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                              maxLines: 2,
                              validator: (v) =>
                                  (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            Autocomplete<String>(
                              key: ValueKey(_autocompleteResetKey),
                              optionsBuilder: (textEditingValue) {
                                if (textEditingValue.text.isEmpty)
                                  return OngkirService.availableCities;
                                return OngkirService.availableCities.where(
                                  (c) => c.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  ),
                                );
                              },
                              initialValue: _kotaTujuan == null
                                  ? null
                                  : TextEditingValue(text: _kotaTujuan!),
                              onSelected: (v) => setState(() {
                                _kotaTujuan = v;
                                _calcOngkir();
                              }),
                              displayStringForOption: (v) => v,
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onSubmitted,
                                  ) {
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        labelText: 'Kota Tujuan *',
                                        prefixIcon: Icon(
                                          Icons.location_city_rounded,
                                        ),
                                      ),
                                      validator: (v) => _kotaTujuan == null
                                          ? 'Pilih kota tujuan'
                                          : null,
                                    );
                                  },
                            ),
                            if (!_originFound) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Kota asal tidak dapat ditentukan — atur di data cabang',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Flexible(
                                  flex: 4,
                                  child: TextFormField(
                                    controller: _penerimaKecC,
                                    decoration: const InputDecoration(
                                      labelText: 'Kecamatan *',
                                      prefixIcon: Icon(Icons.map_rounded),
                                      hintText: 'Contoh: Margahayu',
                                    ),
                                    textCapitalization: TextCapitalization.none,
                                    validator: (v) => (v?.isEmpty ?? true)
                                        ? 'Wajib diisi'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  flex: 1,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final result = await LocationPicker.show(
                                        context,
                                        latitude: _penerimaLat,
                                        longitude: _penerimaLng,
                                        address: _penerimaKecC.text.isNotEmpty
                                            ? _penerimaKecC.text.trim()
                                            : null,
                                      );
                                      if (result != null) {
                                        setState(() {
                                          _penerimaLat = result.latitude;
                                          _penerimaLng = result.longitude;
                                        });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _penerimaLat != null
                                          ? Colors.green
                                          : const Color(0xFF64748B),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size(double.infinity, 56),
                                    ),
                                    child:
                                        MediaQuery.of(context).size.width >= 800
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.gps_fixed,
                                                size: 28,
                                              ),
                                              const SizedBox(width: 4),
                                              const Flexible(
                                                child: Text(
                                                  'Pin Koordinat',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Icon(Icons.gps_fixed, size: 28),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pengirim Card
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _sectionTitle(
                                    'DATA PENGIRIM',
                                    Icons.send_rounded,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.history_rounded,
                                    size: 20,
                                    color: Colors.indigo,
                                  ),
                                  tooltip: 'Riwayat Pengirim',
                                  onPressed: () {
                                    _showRecentPicker(
                                      title: 'Riwayat Pengirim',
                                      type: 'pengirim',
                                      onSelected: (item) {
                                        setState(() {
                                          _pengirimNameC.text = _formatAddress(
                                            item['name'] ?? '',
                                          );
                                          _pengirimPhoneC.text =
                                              _formatPhoneDisplay(
                                                item['phone'] ?? '',
                                              );
                                          _pengirimAddrC.text = _formatAddress(
                                            item['address'] ?? '',
                                          );
                                        });
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _pengirimNameC,
                              decoration: const InputDecoration(
                                labelText: 'Nama Pengirim *',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (v) =>
                                  (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pengirimPhoneC,
                              decoration: const InputDecoration(
                                labelText: 'Kontak Pengirim *',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) =>
                                  (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pengirimAddrC,
                              decoration: const InputDecoration(
                                labelText: 'Alamat Lengkap Pengirim *',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                              maxLines: 2,
                              validator: (v) =>
                                  (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Paket Card
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'RINCIAN BARANG KIRIMAN',
                              Icons.inventory_2_rounded,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _beratC,
                                    decoration: const InputDecoration(
                                      labelText: 'Berat *',
                                      prefixIcon: Icon(Icons.scale_rounded),
                                      suffixText: 'kg',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) =>
                                        (v?.isEmpty ?? true) ? 'Wajib' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _koliC,
                                    decoration: const InputDecoration(
                                      labelText: 'Jumlah Koli *',
                                      prefixIcon: Icon(Icons.apps_rounded),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) =>
                                        (v?.isEmpty ?? true) ? 'Wajib' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _biayaC,
                              decoration: const InputDecoration(
                                labelText: 'Biaya Kirim',
                                prefixIcon: Icon(Icons.payments_rounded),
                                prefixText: 'Rp ',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            if (_ongkirResult != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE0E7FF),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Estimasi',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        Text(
                                          _ongkirResult!.est,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6366F1),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '5 kg pertama',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        Text(
                                          NumberFormat.currency(
                                            locale: 'id_ID',
                                            symbol: 'Rp ',
                                            decimalDigits: 0,
                                          ).format(_ongkirResult!.min),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '/kg selanjutnya',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        Text(
                                          NumberFormat.currency(
                                            locale: 'id_ID',
                                            symbol: 'Rp ',
                                            decimalDigits: 0,
                                          ).format(_ongkirResult!.perkg),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          NumberFormat.currency(
                                            locale: 'id_ID',
                                            symbol: 'Rp ',
                                            decimalDigits: 0,
                                          ).format(_ongkirResult!.total),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF6366F1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Jenis Pembayaran Card
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'JENIS PEMBAYARAN',
                              Icons.payments_rounded,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _paymentChip('Cash', 'cash'),
                                const SizedBox(width: 8),
                                _paymentChip('COD', 'cod'),
                                const SizedBox(width: 8),
                                _paymentChip('Tempo', 'tempo'),
                              ],
                            ),
                            if (_jenisPembayaran == 'cod') ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFFE082),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        size: 16, color: Color(0xFFF57F17)),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Pembayaran akan dikonfirmasi oleh cabang last mile yang mengirimkan ke penerima.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF795548),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_jenisPembayaran == 'tempo') ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFA5D6A7),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        size: 16, color: Color(0xFF2E7D32)),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Pembayaran akan dikonfirmasi oleh cabang asal atau super admin.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF33691E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      size: 16, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Jatuh tempo: ${_tempoLabel(_tempoHari.toInt())}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [7, 14, 30, 60].map((d) {
                                  final selected = _tempoHari.toInt() == d;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: GestureDetector(
                                        onTap: () =>
                                            setState(() => _tempoHari = d.toDouble()),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? const Color(0xFF2E7D32)
                                                : const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: selected
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFE0E0E0),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _tempoLabel(d),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: selected
                                                    ? Colors.white
                                                    : const Color(0xFF616161),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.print_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text('Cetak Resi & Buat Transaksi'),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  String _tempoLabel(int days) {
    if (days == 30) return '1 Bulan';
    if (days == 60) return '2 Bulan';
    return '$days Hari';
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _paymentChip(String label, String value) {
    final selected = _jenisPembayaran == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _jenisPembayaran = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 54,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Detail pengiriman barang telah disimpan ke sistem.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Ticket Card Layout
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'NOMOR RESI PENGIRIMAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BarcodeDisplay(data: _createdTransaction!.noResi),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => LabelPrinter.printBarcodeLabel(
                          data: _createdTransaction!.noResi,
                          pengirim: _createdTransaction!.pengirim,
                          penerima: _createdTransaction!.penerima,
                          paket: _createdTransaction!.paket,
                          createdAt: _createdTransaction!.createdAt,
                          asal:
                              _createdTransaction!.createdBy['cabang_name']
                                  ?.toString() ??
                              _createdTransaction!.createdBy['konter_name']
                                  ?.toString() ??
                              _createdTransaction!.createdBy['gudang_name']
                                  ?.toString(),
                          isCOD: _createdTransaction!.jenisPembayaran == 'cod',
                        ),
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Cetak Resi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _reset();
                    _createdTransaction = null;
                  });
                },
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Buat Transaksi Baru'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Kembali ke Dashboard'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reset() {
    _pengirimNameC.clear();
    _pengirimPhoneC.clear();
    _pengirimAddrC.clear();
    _penerimaNameC.clear();
    _penerimaPhoneC.clear();
    _penerimaAddrC.clear();
    _penerimaKecC.clear();
    _beratC.clear();
    _koliC.text = '1';
    _biayaC.clear();
    setState(() {
      _kotaTujuan = null;
      _penerimaLat = null;
      _penerimaLng = null;
      _ongkirResult = null;
      _autocompleteResetKey++;
      _jenisPembayaran = 'cash';
      _tempoHari = 14;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if ((_jenisPembayaran == 'cod' || _jenisPembayaran == 'tempo') &&
        (_biayaC.text.isEmpty || (double.tryParse(_biayaC.text) ?? 0) <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biaya kirim wajib diisi untuk pembayaran COD/Tempo'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final tx = await repo.create(
        pengirim: {
          'name': _pengirimNameC.text.trim(),
          'phone': _pengirimPhoneC.text.replaceAll(RegExp(r'[^0-9]'), ''),
          'address': _pengirimAddrC.text.trim(),
        },
        penerima: {
          'name': _penerimaNameC.text.trim(),
          'phone': _penerimaPhoneC.text.replaceAll(RegExp(r'[^0-9]'), ''),
          'address': _penerimaAddrC.text.trim(),
          'kecamatan': _penerimaKecC.text.trim(),
          'kota': _kotaTujuan ?? '',
        },
        paket: {
          'berat_kg': double.tryParse(_beratC.text) ?? 0,
          'jumlah_koli': int.tryParse(_koliC.text) ?? 1,
          'biaya_kirim': double.tryParse(_biayaC.text) ?? 0,
        },
        lokasiPenerima: _penerimaLat != null && _penerimaLng != null
            ? {
                'type': 'Point',
                'coordinates': [_penerimaLng, _penerimaLat],
              }
            : null,
        jenisPembayaran: _jenisPembayaran,
        tempoHari: _jenisPembayaran == 'tempo' ? _tempoHari.toInt() : null,
      );
      SoundPlayer.instance.playSuccess();
      setState(() => _createdTransaction = tx);
    } catch (e) {
      SoundPlayer.instance.playError();
      if (mounted) {
        final msg = e is DioException
            ? (e.response?.data?['message'] as String? ??
                  'Gagal membuat transaksi')
            : 'Gagal membuat transaksi';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _submitting = false);
    }
  }
}
