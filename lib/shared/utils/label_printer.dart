import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class LabelPrinter {
  static Future<pw.Font> _loadHiraFont() async {
    final data = await rootBundle.load('assets/pics/hiralogo.ttf');
    return pw.Font.ttf(data);
  }

  static Future<void> printBarcodeLabel({
    required String data,
    Map<String, dynamic>? pengirim,
    Map<String, dynamic>? penerima,
    Map<String, dynamic>? paket,
    DateTime? createdAt,
    String? asal,
    String? dicetakOleh,
  }) async {
      final jumlahKoli = (paket?['jumlah_koli'] as num?)?.toInt() ?? 1;
      final hiraFont = await _loadHiraFont();

      await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();

        for (var i = 1; i <= jumlahKoli; i++) {
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
                        'Hira Express',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
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
                    if (asal != null && asal.isNotEmpty) ...[
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: pw.Text(
                              dicetakOleh != null && asal != dicetakOleh
                                  ? 'Resi ini dicetak ulang (Cabang $dicetakOleh)'
                                  : 'Cabang $asal',
                          style: pw.TextStyle(
                            fontSize: 7,
                            color: dicetakOleh != null && asal != dicetakOleh
                                ? PdfColors.red700
                                : PdfColors.black,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
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
                              if (penerima != null && pengirim != null) ...[
                                pw.Divider(height: 1, thickness: 0.3),
                                pw.SizedBox(height: 2),
                              ],
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
                              pw.SizedBox(height: 6),
                              pw.Center(
                                child: pw.Text(
                                  String.fromCharCode(0xe000),
                                  style: pw.TextStyle(font: hiraFont, fontSize: 25),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.black, width: 0.5),
                            ),
                            child: pw.Text(
                              _capitalize(penerima?['kecamatan'] as String? ?? ''),
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 3),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.black, width: 0.5),
                            ),
                            child: pw.Text(
                              penerima?['kota'] as String? ?? '',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Divider(height: 1),
                    pw.SizedBox(height: 2),
                    if (paket != null) _paketLine(paket, createdAt),
                    if (jumlahKoli > 1) ...[
                      pw.SizedBox(height: 3),
                      pw.Container(
                        color: PdfColors.black,
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Center(
                          child: pw.Text(
                            'Koli $i/$jumlahKoli',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        }

        return doc.save();
      },
    );
  }

  /// Cetak label retur dengan data resi asli, alamat penerima/pengirim swapped.
  /// - [data] nomor resi asli
  /// - [penerima] diisi data PENGIRIM asli (karena retur dikembalikan ke pengirim)
  /// - [pengirim] diisi data cabang yang melakukan retur
  /// - [paket] data paket sama
  /// - [createdAt] tanggal buat
  /// - [dicetakOleh] nama cabang yang mencetak
  /// - [originalResi] nomor resi asli untuk referensi
  static Future<void> printReturLabel({
    required String data,
    required Map<String, dynamic> penerima,
    required Map<String, dynamic> pengirim,
    Map<String, dynamic>? paket,
    DateTime? createdAt,
    String? dicetakOleh,
    String? asalCabang,
  }) async {
    final jumlahKoli = (paket?['jumlah_koli'] as num?)?.toInt() ?? 1;
    final hiraFont = await _loadHiraFont();

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();

        for (var i = 1; i <= jumlahKoli; i++) {
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(78 * PdfPageFormat.mm, 100 * PdfPageFormat.mm),
              margin: const pw.EdgeInsets.only(left: 5, right: 2, top: 3, bottom: 3),
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Label RETUR
                    pw.Container(
                      color: PdfColors.orange700,
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Center(
                        child: pw.Text(
                          'RESI RETUR',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Divider(height: 1),
                    pw.SizedBox(height: 3),
                    // Barcode
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
                    // Penerima (pengirim asli) + Pengirim (cabang retur)
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: [
                              _infoCard('Penerima (Retur)', penerima),
                              pw.Divider(height: 1, thickness: 0.3),
                              pw.SizedBox(height: 2),
                              _infoCard(
                                'Pengirim',
                                {
                                  'name': 'Cabang ${pengirim['name'] ?? ''}',
                                  'phone': pengirim['phone'] ?? '',
                                  'address': pengirim['address'] ?? '',
                                },
                              ),
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
                              pw.SizedBox(height: 6),
                              pw.Center(
                                child: pw.Text(
                                  String.fromCharCode(0xe000),
                                  style: pw.TextStyle(font: hiraFont, fontSize: 25),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    // 1 kotak: nama cabang asal origin
                    if (asalCabang != null && asalCabang.isNotEmpty)
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 0.5),
                        ),
                        child: pw.Text(
                          asalCabang,
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    pw.SizedBox(height: 2),
                    pw.Divider(height: 1),
                    pw.SizedBox(height: 2),
                    if (paket != null) _paketLine(paket, createdAt),
                    if (jumlahKoli > 1) ...[
                      pw.SizedBox(height: 3),
                      pw.Container(
                        color: PdfColors.black,
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Center(
                          child: pw.Text(
                            'Koli $i/$jumlahKoli',
                            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        }

        return doc.save();
      },
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
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

  static String _formatDibuat(DateTime dt) {
    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    final day = days[dt.weekday - 1];
    final date = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    return 'Dibuat : $day, $date $month $year';
  }

  static pw.Widget _infoCard(String label, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    final address = data['address'] as String? ?? '';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          '$label: $name',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          maxLines: 2,
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
    );
  }

  static pw.Widget _paketLine(Map<String, dynamic> paket, DateTime? createdAt) {
    final berat = paket['berat_kg'] ?? '0';
    final koli = paket['jumlah_koli'] ?? '0';
    final biaya = paket['biaya_kirim'] as num? ?? 0;
    return pw.Column(
      children: [
        if (createdAt != null) ...[
          pw.Center(
            child: pw.Text(
              _formatDibuat(createdAt),
              style: pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.SizedBox(height: 3),
        ],
        pw.Row(
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
        ),
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
