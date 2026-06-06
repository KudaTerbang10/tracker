import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class LabelPrinter {
  static Future<void> printBarcodeLabel({
    required String data,
    Map<String, dynamic>? pengirim,
    Map<String, dynamic>? penerima,
    Map<String, dynamic>? paket,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(78 * PdfPageFormat.mm, 100 * PdfPageFormat.mm),
            margin: const pw.EdgeInsets.only(left: 5, right: 2, top: 3, bottom: 3),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'Pravda Express',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Divider(height: 1),
                  pw.SizedBox(height: 3),
                  pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: data,
                      width: 68 * PdfPageFormat.mm,
                      height: 20 * PdfPageFormat.mm,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Divider(height: 1),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            if (penerima != null)
                              _infoCard('Penerima', penerima),
                            if (pengirim != null && penerima != null)
                              pw.SizedBox(height: 3),
                            if (pengirim != null)
                              _infoCard('Pengirim', pengirim),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 2),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.SizedBox(height: 4),
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: data,
                              width: 22 * PdfPageFormat.mm,
                              height: 22 * PdfPageFormat.mm,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Divider(height: 1),
                  pw.SizedBox(height: 2),
                  if (paket != null) _paketLine(paket),
                ],
              );
            },
          ),
        );

        return doc.save();
      },
    );
  }

  static String _thousands(dynamic val) {
    if (val == null) return '0';
    final n = val is num ? val : double.tryParse(val.toString()) ?? 0;
    final s = n.toStringAsFixed(0);
    var out = '';
    var count = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) out = '.$out';
      out = s[i] + out;
      count++;
    }
    return out;
  }

  static pw.Widget _infoCard(String label, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    final address = data['address'] as String? ?? '';
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            '$label: $name',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          if (phone.isNotEmpty) ...[
            pw.SizedBox(height: 1),
            pw.Text('[ $phone ]', style: pw.TextStyle(fontSize: 8)),
          ],
          if (address.isNotEmpty) ...[
            pw.SizedBox(height: 1),
            pw.Text(address, style: pw.TextStyle(fontSize: 8), maxLines: 2),
          ],
        ],
      ),
    );
  }

  static pw.Widget _paketLine(Map<String, dynamic> paket) {
    final berat = paket['berat_kg'] ?? '0';
    final koli = paket['jumlah_koli'] ?? '0';
    final biaya = paket['biaya_kirim'] as num? ?? 0;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        _paketItem('Berat : $berat kg'),
        _sep(),
        _paketItem('Koli : $koli'),
        if (biaya > 0) ...[
          _sep(),
          _paketItem('Rp ${_thousands(biaya)}'),
        ],
      ],
    );
  }

  static pw.Widget _sep() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2),
      child: pw.Text('|', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
    );
  }

  static pw.Widget _paketItem(String text) {
    return pw.Text(text, style: pw.TextStyle(fontSize: 8));
  }
}
