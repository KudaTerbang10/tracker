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
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _copy(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.content_copy_rounded, size: 16, color: primary),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _copy(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primary.withValues(alpha: 0.15), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.content_copy_rounded, size: 14, color: primary),
              const SizedBox(width: 6),
              Text(
                'Salin',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
