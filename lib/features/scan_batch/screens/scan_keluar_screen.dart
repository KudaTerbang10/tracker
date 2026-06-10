import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/datasources/local/hive_cache.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/widgets/barcode_scanner_dialog.dart';
import '../../../shared/widgets/resi_copy_button.dart';
import '../../../shared/utils/sound_player.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/scan_batch_provider.dart';

class ScanKeluarScreen extends ConsumerStatefulWidget {
  const ScanKeluarScreen({super.key});
  @override
  ConsumerState<ScanKeluarScreen> createState() => _ScanKeluarScreenState();
}

class _ScanKeluarScreenState extends ConsumerState<ScanKeluarScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanKeluarProvider);
    final notifier = ref.read(scanKeluarProvider.notifier);
    final validCount = state.validCount;
    final role = ref.read(authProvider).user?.role ?? '';
    final isAdminCabang = role == 'admin_cabang';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barang Keluar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: state.scannedItems.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset',
                  onPressed: () => notifier.clear(),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          if (isAdminCabang && state.scannedItems.any((i) => i.isValid)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, size: 20, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Data Driver & Tujuan',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _DriverAutocompleteField(
                        onSelected: (d) => notifier.setDriver(
                          d['user_id'].toString(),
                          d['name'].toString(),
                          d['phone'].toString(),
                        ),
                        onManualChanged: (name) {
                          if (name.trim().isNotEmpty) {
                            notifier.setDriverManual(name.trim(), '');
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilterChip(
                            label: const Text('Ke Cabang Lain'),
                            selected: state.tujuanType == TujuanType.cabang,
                            onSelected: (v) {
                              if (!state.driverLocked) {
                                notifier.setTujuanType(TujuanType.cabang);
                              }
                            },
                            selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                            checkmarkColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: state.tujuanType == TujuanType.cabang ? FontWeight.w700 : FontWeight.w500,
                              color: state.tujuanType == TujuanType.cabang ? AppTheme.primary : const Color(0xFF64748B),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: state.tujuanType == TujuanType.cabang ? AppTheme.primary : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                          ),
                          if (isAdminCabang) ...[
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('Langsung ke Penerima'),
                              selected: state.tujuanType == TujuanType.penerima,
                              onSelected: (v) {
                                if (!state.driverLocked) {
                                  notifier.setTujuanType(TujuanType.penerima);
                                }
                              },
                              selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                              checkmarkColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: state.tujuanType == TujuanType.penerima ? FontWeight.w700 : FontWeight.w500,
                                color: state.tujuanType == TujuanType.penerima ? AppTheme.primary : const Color(0xFF64748B),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: state.tujuanType == TujuanType.penerima ? AppTheme.primary : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (state.tujuanType == TujuanType.cabang) ...[
                        const SizedBox(height: 12),
                        _CabangAutocompleteField(
                          excludeCabangId: ref.read(authProvider).user?.cabangId,
                          onSelected: (c) => notifier.setCabangTujuan(
                            c['cabang_id'].toString(),
                            c['name'].toString(),
                          ),
                          onManualChanged: (name) {
                            if (name.trim().isNotEmpty) {
                              notifier.setCabangTujuanManual(name.trim());
                            }
                          },
                        ),
                      ],
                      if (state.tujuanType == TujuanType.penerima) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.15), width: 1),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.info_rounded, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Paket akan dikirim langsung ke alamat penerima',
                                  style: TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (state.scannedItems.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '$validCount barang valid',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (validCount < state.scannedItems.length)
                    Text(
                      ' | ${state.scannedItems.length - validCount} tidak valid',
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  const Spacer(),
                  Text(
                    'Total: ${state.scannedItems.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: state.scannedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code_scanner,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tekan "SCAN" untuk mulai 📷',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                        ),
                        Text(
                          'Scan barcode barang yang akan keluar',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: state.scannedItems.length,
                    itemBuilder: (_, i) {
                      final item = state.scannedItems[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            item.isValid ? Icons.check_circle : Icons.error,
                            color: item.isValid ? Colors.green : AppTheme.error,
                          ),
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  item.noResi,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              ResiCopyButton(resi: item.noResi),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item.transaction.pengirimName} → ${item.transaction.penerimaName}',
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _badge(item.transaction.beratLabel, Colors.blue),
                                  const SizedBox(width: 6),
                                  _badge(item.transaction.koliLabel, Colors.orange),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.isValid
                                    ? 'Siap diproses'
                                    : item.errorMessage ?? 'Tidak valid',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: item.isValid ? Colors.green : AppTheme.error,
                                ),
                              ),
                            ],
                          ),
                          trailing: GestureDetector(
                            onLongPress: () => notifier.removeItem(item.noResi),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.close, size: 16, color: Colors.red.shade700),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (state.scannedItems.isNotEmpty)
                GestureDetector(
                  onLongPress: () => notifier.clear(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close, color: Colors.red.shade700, size: 20),
                  ),
                ),
              if (state.scannedItems.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                flex: state.scannedItems.isNotEmpty ? 1 : 1,
                child: ElevatedButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('SCAN'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (validCount > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: _submitting
                        ? null
                        : () => _confirm(context, ref),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('KONFIRMASI'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processResi(String code) async {
    final alreadyScanned =
        ref.read(scanKeluarProvider).scannedItems.any((i) => i.noResi == code);
    if (alreadyScanned) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resi $code sudah discan sebelumnya')),
        );
      }
      return;
    }

    try {
      final res = await ApiService().get('${ApiConstants.track}/$code');
      final tx = Transaction.fromJson(res.data as Map<String, dynamic>);

      bool isValid = false;
      String? error;
      final role = ref.read(authProvider).user?.role ?? '';

      if (role == 'admin_cabang') {
        isValid = true;
        SoundPlayer.instance.playScan();
      } else {
        error = 'Role tidak memiliki akses scan keluar';
      }

      ref
          .read(scanKeluarProvider.notifier)
          .addItem(
            ScanItem(
              noResi: code,
              transaction: tx,
              isValid: isValid,
              errorMessage: error,
            ),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Resi $code tidak ditemukan')));
      }
    }
  }

  Future<void> _scan() async {
    final code = await BarcodeScannerDialog.show(
      context,
      label: 'Scan barcode barang keluar',
    );
    if (code == null || code.isEmpty) return;
    await _processResi(code);
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final state = ref.read(scanKeluarProvider);
    final role = ref.read(authProvider).user?.role ?? '';
    final validItems = state.scannedItems.where((i) => i.isValid).toList();

    if (validItems.isEmpty) return;

    final hasDriver =
        (state.driverUserId != null && state.driverUserId!.isNotEmpty) ||
        (state.driverName != null && state.driverName!.isNotEmpty);
    if (!hasDriver) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama Driver wajib diisi'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (state.tujuanType == TujuanType.cabang) {
      final hasCabang =
          (state.cabangTujuanId != null && state.cabangTujuanId!.isNotEmpty) ||
          (state.cabangTujuanNama != null &&
              state.cabangTujuanNama!.isNotEmpty);
      if (!hasCabang) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cabang tujuan wajib diisi'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text(
          'Kirim ${validItems.length} barang dengan Driver ${state.driverName ?? "-"}?',
        ),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: const Text('KONFIRMASI'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('BATAL'),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final statusBaru = 'keluar_cabang';

      final result = await repo.batchUpdateStatus(
        noResiList: validItems.map((i) => i.noResi).toList(),
        statusBaru: statusBaru,
        driverUserId: state.driverUserId,
        tipeTujuan: state.tujuanType == TujuanType.cabang
            ? 'cabang'
            : 'penerima',
        cabangTujuanId: state.tujuanType == TujuanType.cabang
            ? state.cabangTujuanId
            : null,
        namaDriverManual: state.driverUserId == null ? state.driverName : null,
        cabangNamaManual:
            (state.tujuanType == TujuanType.cabang &&
                state.cabangTujuanId == null)
            ? state.cabangTujuanNama
            : null,
      );

      if (mounted) {
        final berhasil = result['berhasil'] as int? ?? 0;
        final gagal = result['gagal'] as int? ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              gagal > 0
                  ? '✅ $berhasil berhasil, ❌ $gagal gagal'
                  : '✅ $berhasil berhasil',
            ),
            backgroundColor: gagal > 0 ? AppTheme.warning : Colors.green,
          ),
        );
        SoundPlayer.instance.playSuccess();
        ref.read(scanKeluarProvider.notifier).clear();
      }
    } catch (e) {
      SoundPlayer.instance.playError();
      if (mounted) {
        final msg = e is DioException
            ? (e.response?.data?['message'] as String? ?? 'Gagal mengirim')
            : 'Gagal mengirim';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DriverAutocompleteField extends StatefulWidget {
  final void Function(Map<String, dynamic>) onSelected;
  final void Function(String) onManualChanged;
  const _DriverAutocompleteField({
    required this.onSelected,
    required this.onManualChanged,
  });

  @override
  State<_DriverAutocompleteField> createState() =>
      _DriverAutocompleteFieldState();
}

class _DriverAutocompleteFieldState extends State<_DriverAutocompleteField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (text) {
        if (text.text.isEmpty) return const Iterable.empty();
        return HiveCache.getDrivers(query: text.text);
      },
      displayStringForOption: (d) => '${d['name']} (${d['phone']})',
      onSelected: (d) {
        _controller.text = d['name'].toString();
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        widget.onSelected(d);
        _focusNode.unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Nama Driver *',
            hintText: 'Ketik untuk cari...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) {
            widget.onManualChanged(v);
          },
        );
      },
      optionsViewBuilder: (context, onSelectedCb, options) {
        if (options.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 32,
                maxHeight: 240,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final d = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(d['name'].toString()),
                    subtitle: Text(d['phone'].toString()),
                    onTap: () {
                      _controller.text = d['name'].toString();
                      _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length,
                      );
                      onSelectedCb(d);
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CabangAutocompleteField extends StatefulWidget {
  final void Function(Map<String, dynamic>) onSelected;
  final void Function(String) onManualChanged;
  final String? excludeCabangId;
  const _CabangAutocompleteField({
    required this.onSelected,
    required this.onManualChanged,
    this.excludeCabangId,
  });

  @override
  State<_CabangAutocompleteField> createState() =>
      _CabangAutocompleteFieldState();
}

class _CabangAutocompleteFieldState extends State<_CabangAutocompleteField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  List<Map<String, dynamic>> _cabangs = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _loadCabangs();
  }

  Future<void> _loadCabangs() async {
    try {
      final res = await ApiService().get('/cabangs');
      final data = res.data['data'] as List<dynamic>;
      if (mounted) {
        setState(() {
          final all = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _cabangs = widget.excludeCabangId != null
              ? all.where((c) => c['cabang_id']?.toString() != widget.excludeCabangId).toList()
              : all;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (text) {
        if (text.text.isEmpty) return const Iterable.empty();
        final q = text.text.toLowerCase();
        return _cabangs.where(
          (c) => (c['name']?.toString() ?? '').toLowerCase().contains(q) ||
              (c['kode']?.toString() ?? '').toLowerCase().contains(q),
        );
      },
      displayStringForOption: (c) => '${c['kode']} - ${c['name']}',
      onSelected: (c) {
        _controller.text = c['name'].toString();
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        widget.onSelected(c);
        _focusNode.unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Cabang Tujuan *',
            hintText: 'Ketik untuk cari...',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) {
            widget.onManualChanged(v);
          },
        );
      },
      optionsViewBuilder: (context, onSelectedCb, options) {
        if (options.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 32,
                maxHeight: 240,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final c = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text('${c['kode']} - ${c['name']}'),
                    subtitle: Text(c['address']?.toString() ?? ''),
                    onTap: () {
                      _controller.text = c['name'].toString();
                      _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length,
                      );
                      onSelectedCb(c);
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
