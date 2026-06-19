import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';

class BarcodeScannerDialog {
  static Future<String?> show(BuildContext context, {String? label}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScannerDialogContent(label: label),
    );
  }
}

class _ScannerDialogContent extends StatefulWidget {
  final String? label;
  const _ScannerDialogContent({this.label});
  @override
  State<_ScannerDialogContent> createState() => _ScannerDialogContentState();
}

class _ScannerDialogContentState extends State<_ScannerDialogContent> with SingleTickerProviderStateMixin {
  bool get _isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  MobileScannerController? _controller;
  String _lastCode = '';
  bool _processing = false;
  late TabController _tabController;
  final _manualC = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!_isWindows) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: false,
      );
    }
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tabController.dispose();
    _manualC.dispose();
    super.dispose();
  }

  void _submitManual() {
    final code = _manualC.text.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    if (_isWindows) {
      return _buildManualDialog(context);
    }
    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Container(
              color: AppTheme.primary,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(icon: Icon(Icons.qr_code_scanner), text: 'Kamera'),
                  Tab(icon: Icon(Icons.keyboard), text: 'Manual'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCameraTab(),
                  _buildManualTab(),
                ],
              ),
            ),
            if (widget.label != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.black87,
                child: Text(
                  widget.label!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Tutup'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualDialog(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Input No. Resi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gunakan scanner USB atau ketik manual',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _manualC,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 18, letterSpacing: 1.5, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'No. Resi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              onSubmitted: (_) => _submitManual(),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _submitManual,
              icon: const Icon(Icons.check),
              label: const Text('OK'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraTab() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: (capture) {
            final code = capture.barcodes.firstOrNull?.rawValue;
            if (code != null && !_processing && code != _lastCode) {
              _lastCode = code;
              _processing = true;
              HapticFeedback.heavyImpact();
              Navigator.of(context).pop(code);
            }
          },
        ),
        Center(
          child: Container(
            width: 250,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.keyboard_alt_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Input Manual No. Resi',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gunakan jika barcode rusak atau tidak bisa dipindai',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _manualC,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 18, letterSpacing: 1.5, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'No. Resi',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code),
            ),
            onSubmitted: (_) => _submitManual(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _submitManual,
            icon: const Icon(Icons.check),
            label: const Text('Tambahkan'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 48),
            ),
          ),
        ],
      ),
    );
  }
}


