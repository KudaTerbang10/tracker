import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/barcode_scanner_dialog.dart';

class CekResiSection extends StatefulWidget {
  final GlobalKey sectionKey;
  const CekResiSection({super.key, required this.sectionKey});

  @override
  State<CekResiSection> createState() => _CekResiSectionState();
}

class _CekResiSectionState extends State<CekResiSection> {
  final _resiC = TextEditingController();

  @override
  void dispose() {
    _resiC.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerDialog.show(context);
    if (code != null && code.isNotEmpty) {
      _resiC.text = code.toUpperCase();
      _track();
    }
  }

  void _track() {
    final resi = _resiC.text.trim().toUpperCase();
    if (resi.isEmpty) return;
    context.go('/track/$resi');
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: widget.sectionKey,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const Text('Cek Resi Pengiriman',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        color: AppTheme.primary)),
                const SizedBox(height: 8),
                const Text(
                    'Lacak posisi terbaru kiriman Anda secara real-time',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.route_rounded,
                              color: AppTheme.primary, size: 40),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _resiC,
                          decoration: InputDecoration(
                            labelText: 'Masukkan No. Resi',
                            hintText: 'Contoh: CKG-20270710-0002',
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: AppTheme.primary, size: 22),
                            suffixIcon: Container(
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: AppTheme.primary,
                                    size: 22),
                                onPressed: _scanBarcode),
                            ),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          onFieldSubmitted: (_) => _track(),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _track,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.track_changes_rounded, size: 22),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text('Lacak Sekarang',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
