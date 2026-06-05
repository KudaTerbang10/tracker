import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResiCopyButton extends StatelessWidget {
  final String resi;
  final bool compact;
  final Color? color;

  const ResiCopyButton({
    super.key,
    required this.resi,
    this.compact = true,
    this.color,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: resi));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No. Resi disalin'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = color ?? Theme.of(context).primaryColor;
    if (compact) {
      return IconButton(
        icon: const Icon(Icons.copy, size: 18),
        onPressed: () => _copy(context),
        tooltip: 'Salin No. Resi',
        visualDensity: VisualDensity.compact,
        color: primary,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      );
    }
    return InkWell(
      onTap: () => _copy(context),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy, size: 14, color: primary),
            const SizedBox(width: 4),
            Text('Salin', style: TextStyle(fontSize: 12, color: primary)),
          ],
        ),
      ),
    );
  }
}
