import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/barcode_scanner_dialog.dart';

class HomeSection extends StatefulWidget {
  final bool isMobile;
  final VoidCallback onLihatCabang;
  const HomeSection({super.key, required this.isMobile, required this.onLihatCabang});

  @override
  State<HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends State<HomeSection> {
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 24 : 64,
        vertical: widget.isMobile ? 48 : 80,
      ),
      child: widget.isMobile ? _buildMobile(context) : _buildWeb(context),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Image.asset('assets/pics/hiralogo.webp', width: 72, height: 72),
        ),
        const SizedBox(height: 24),
        const Text('Hira Express', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 32, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Text('Lacak kiriman Anda secara real-time', style: TextStyle(color: Color(0xFF64748B), fontSize: 16), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        _buildTrackingCard(true),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildWeb(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final targetHeight = (screenHeight * 0.55).clamp(300.0, 500.0);

    return LayoutBuilder(
      builder: (context, innerConstraints) {
        final maxWidth = innerConstraints.maxWidth > 1100 ? 1100.0 : innerConstraints.maxWidth;
        final colWidth = (maxWidth - 64) / 2;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: colWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6))]),
                        child: Image.asset('assets/pics/hiralogo.webp', width: 112, height: 112),
                      ),
                      const SizedBox(height: 32),
                      const Text('Hira Express', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 48, letterSpacing: -1)),
                      const SizedBox(height: 16),
                      const Text('Lacak kiriman Anda secara real-time dengan mudah dan cepat. Solusi logistik terpercaya untuk kebutuhan pengiriman Anda.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 18, height: 1.6)),
                    ],
                  ),
                ),
                const SizedBox(width: 64),
                SizedBox(width: colWidth, height: targetHeight, child: Center(child: _buildTrackingCard(false))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrackingCard(bool isMobile) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            isMobile
                ? Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                        child: const Icon(Icons.route_rounded, color: Colors.white, size: 48),
                      ),
                      const SizedBox(height: 16),
                      const Text('Hira Tracking System', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF0F172A))),
                      const SizedBox(height: 24),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                        child: const Icon(Icons.route_rounded, color: Colors.white, size: 40),
                      ),
                      const SizedBox(width: 16),
                      const Flexible(child: Text('Hira Tracking System', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
            Column(
              children: [
                TextFormField(
                  controller: _resiC,
                  decoration: InputDecoration(
                    labelText: 'Masukkan No. Resi',
                    hintText: 'Contoh: CKG-20270710-0002',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 22),
                    suffixIcon: Container(
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                      child: IconButton(icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary, size: 22), onPressed: _scanBarcode),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onFieldSubmitted: (_) => _track(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _track,
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.track_changes_rounded, size: 22),
                        SizedBox(width: 10),
                        Flexible(child: Text('Lacak Sekarang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
