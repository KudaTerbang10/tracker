import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';

class BarcodeScannerDialog extends StatelessWidget {
  final String? label;
  final bool autoClose;

  const BarcodeScannerDialog({
    super.key,
    this.label,
    this.autoClose = true,
  });

  static Future<String?> show(BuildContext context, {String? label}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScannerDialogContent(label: label),
    );
  }

  static Future<List<String>?> showBulk(BuildContext context, {String? label}) {
    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BulkScannerContent(label: label),
    );
  }

  @override
  Widget build(BuildContext context) => _ScannerDialogContent(label: label);
}

class _ScannerDialogContent extends StatefulWidget {
  final String? label;
  const _ScannerDialogContent({this.label});
  @override
  State<_ScannerDialogContent> createState() => _ScannerDialogContentState();
}

class _ScannerDialogContentState extends State<_ScannerDialogContent> with SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  String _lastCode = '';
  bool _processing = false;
  late TabController _tabController;
  final _manualC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
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

class _BulkScannerContent extends StatefulWidget {
  final String? label;
  const _BulkScannerContent({this.label});
  @override
  State<_BulkScannerContent> createState() => _BulkScannerContentState();
}

class _BulkScannerContentState extends State<_BulkScannerContent> with SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  final List<String> _codes = [];
  bool _processing = false;
  late TabController _tabController;
  final _manualC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tabController.dispose();
    _manualC.dispose();
    super.dispose();
  }

  void _addCode(String code) {
    if (_codes.contains(code)) return;
    setState(() => _codes.add(code));
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Container(
              color: AppTheme.primary,
              child: SafeArea(
                bottom: false,
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
            if (_codes.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 90),
                color: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: _codes.asMap().entries.map((e) => Chip(
                      label: Text(e.value, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setState(() => _codes.removeAt(e.key)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.only(left: 6),
                    )).toList(),
                  ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Tutup'),
                    ),
                    if (_codes.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(_codes.toList()),
                        icon: const Icon(Icons.check),
                        label: Text('SELESAI (${_codes.length})'),
                      ),
                    ],
                  ],
                ),
              ),
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
            if (code != null && !_processing) {
              _processing = true;
              _addCode(code);
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) setState(() => _processing = false);
              });
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 18, letterSpacing: 1.5, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'No. Resi',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code),
            ),
            onSubmitted: (v) {
              final code = v.trim().toUpperCase();
              if (code.isNotEmpty) {
                _addCode(code);
                _manualC.clear();
              }
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final code = _manualC.text.trim().toUpperCase();
              if (code.isNotEmpty) {
                _addCode(code);
                _manualC.clear();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambahkan'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ],
      ),
    );
  }
}
