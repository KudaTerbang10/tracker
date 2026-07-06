import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PaymentReportPrinter {
  static pw.Font? _cachedHiraFont;

  static Future<pw.Font> _getHiraFont() async {
    if (_cachedHiraFont != null) return _cachedHiraFont!;
    final data = await rootBundle.load('assets/pics/hiralogo.ttf');
    _cachedHiraFont = pw.Font.ttf(data);
    return _cachedHiraFont!;
  }

  static Future<void> printReport({
    required int month,
    required int year,
    required List<Map<String, dynamic>> data,
    required String jenis,
    String? cabangName,
  }) async {
    final hiraFont = await _getHiraFont();
    final isCOD = jenis == 'cod';
    final title = isCOD ? 'LAPORAN COD' : 'LAPORAN TEMPO';
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final monthName = months[month - 1];
    final headerColor = isCOD ? PdfColors.amber800 : PdfColors.green800;

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  _buildHeader(hiraFont, title, monthName, year, headerColor, cabangName),
                  pw.SizedBox(height: 16),
                  _buildTable(data, isCOD: isCOD),
                  pw.SizedBox(height: 12),
                  _buildFooter(),
                ],
              );
            },
          ),
        );

        if (data.length > 25) {
          for (var page = 1; page * 25 < data.length; page++) {
            final start = page * 25;
            final end = start + 25 > data.length ? data.length : start + 25;
            final pageData = data.sublist(start, end);

            doc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(24),
                build: (pw.Context context) {
                  return pw.Column(
                    children: [
                      _buildHeader(hiraFont, title, monthName, year, headerColor, cabangName),
                      pw.SizedBox(height: 16),
                      _buildTable(pageData, startIndex: start, isCOD: isCOD),
                      pw.SizedBox(height: 12),
                      _buildFooter(),
                    ],
                  );
                },
              ),
            );
          }
        }

        return doc.save();
      },
    );
  }

  static pw.Widget _buildHeader(pw.Font hiraFont, String title, String monthName, int year, PdfColor accentColor, String? cabangName) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              String.fromCharCode(0xe000),
              style: pw.TextStyle(
                font: hiraFont,
                fontSize: 40,
                color: PdfColors.red700,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'HIRA EXPRESS',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    title + (cabangName != null && cabangName.isNotEmpty ? ' - $cabangName' : ''),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Periode: $monthName $year',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.5, color: accentColor),
      ],
    );
  }

  static pw.Widget _buildTable(List<Map<String, dynamic>> data, {int startIndex = 0, required bool isCOD}) {
    final headerColor = isCOD ? PdfColors.amber800 : PdfColors.green800;
    final summaryColor = isCOD ? PdfColors.amber100 : PdfColors.green100;
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final totalLunas = data.where((r) => r['status_pembayaran'] == 'paid').length;
    final totalNominal = data.fold<int>(0, (sum, r) => sum + ((r['biaya_kirim'] as num?)?.toInt() ?? 0));

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: headerColor),
        children: [
          _headerCell('No', 0.3),
          _headerCell('No. Resi', 1.8),
          _headerCell('Pengirim', 1.6),
          _headerCell('Penerima', 1.6),
          _headerCell('Nominal', 1.2),
          _headerCell('Status', 0.8),
        ],
      ),
    ];

    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      final isEven = i % 2 == 0;
      final isPaid = row['status_pembayaran'] == 'paid';
      final nominal = row['biaya_kirim'] as num? ?? 0;

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: isEven ? PdfColors.grey50 : PdfColors.white),
          children: [
            _dataCell('${startIndex + i + 1}', 0.3, align: pw.TextAlign.center),
            _dataCell(row['no_resi'] as String? ?? '-', 1.8),
            _dataCell(row['pengirim'] as String? ?? '-', 1.6),
            _dataCell(row['penerima'] as String? ?? '-', 1.6),
            _dataCell(currencyFmt.format(nominal), 1.2, align: pw.TextAlign.right),
            _dataCell(
              isPaid ? 'Lunas' : 'Belum Lunas',
              0.8,
              align: pw.TextAlign.center,
              fontWeight: pw.FontWeight.bold,
              color: isPaid ? PdfColors.green700 : PdfColors.red700,
            ),
          ],
        ),
      );
    }

    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: summaryColor),
        children: [
          _dataCell('', 0.3),
          _dataCell('TOTAL', 1.8, fontWeight: pw.FontWeight.bold),
          _dataCell('', 1.6),
          _dataCell('${data.length} Resi', 1.6, fontWeight: pw.FontWeight.bold),
          _dataCell(currencyFmt.format(totalNominal), 1.2, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
          _dataCell('$totalLunas Lunas', 0.8, align: pw.TextAlign.center, fontWeight: pw.FontWeight.bold),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(0.3),
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.6),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(0.8),
      },
      children: rows,
    );
  }

  static pw.Widget _buildFooter() {
    final now = DateTime.now();
    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final dateStr = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Dicetak pada: $dateStr', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Dicetak oleh: Super Admin', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _headerCell(String text, double flex, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: align),
    );
  }

  static pw.Widget _dataCell(String text, double flex, {pw.TextAlign align = pw.TextAlign.left, pw.FontWeight? fontWeight, PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 7.5, fontWeight: fontWeight, color: color), textAlign: align),
    );
  }
}
