import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';

class BarcodeDisplay extends StatelessWidget {
  final String data;
  final double height;

  const BarcodeDisplay({super.key, required this.data, this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BarcodeWidget(
          barcode: Barcode.code128(),
          data: data,
          width: MediaQuery.of(context).size.width - 80,
          height: height,
          drawText: false,
          style: const TextStyle(fontSize: 0),
        ),
        const SizedBox(height: 8),
        Text(data, style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
