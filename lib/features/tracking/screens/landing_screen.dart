import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/barcode_scanner_dialog.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _resiC = TextEditingController();

  @override
  void dispose() {
    _resiC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2, size: 100, color: AppTheme.primary),
                const SizedBox(height: 12),
                Text('Ekspedisi Tracker', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Lacak kiriman Anda', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _resiC,
                  decoration: InputDecoration(
                    labelText: 'Masukkan No. Resi',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanBarcode,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onFieldSubmitted: (_) => _track(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _track,
                    child: const Text('Lacak Kiriman'),
                  ),
                ),
                const SizedBox(height: 32),
                TextButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Login Staff'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
}
