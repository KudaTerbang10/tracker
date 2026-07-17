import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class BranchReportPrinter {
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
  }) async {
    final hiraFont = await _getHiraFont();

    final doc = pw.Document();
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final monthName = months[month - 1];
    const limit = 25;

    // Page 1: first 25 rows
    final firstBatch = data.sublist(0, data.length > limit ? limit : data.length);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              _buildHeader(hiraFont, monthName, year),
              pw.SizedBox(height: 16),
              _buildTable(firstBatch),
              pw.SizedBox(height: 12),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    // Page 2+: remaining rows
    if (data.length > limit) {
      for (var page = 1; page * limit < data.length; page++) {
        final start = page * limit;
        final end = start + limit > data.length ? data.length : start + limit;
        final pageData = data.sublist(start, end);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  _buildHeader(hiraFont, monthName, year),
                  pw.SizedBox(height: 16),
                  _buildTable(pageData, startIndex: start),
                  pw.SizedBox(height: 12),
                  _buildFooter(),
                ],
              );
            },
          ),
        );
      }
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => doc.save(),
    );
  }

  static pw.Widget _buildHeader(pw.Font hiraFont, String monthName, int year) {
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
                    'LAPORAN PER CABANG',
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
        pw.Divider(thickness: 1.5, color: PdfColors.indigo700),
      ],
    );
  }

  static pw.Widget _buildTable(List<Map<String, dynamic>> data, {int startIndex = 0}) {
    final totalResi = data.fold<int>(0, (sum, row) => sum + ((row['total_resi'] as num?)?.toInt() ?? 0));
    final totalBiaya = data.fold<double>(0, (sum, row) => sum + ((row['total_biaya'] as num?)?.toDouble() ?? 0));

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.indigo700),
        children: [
          _headerCell('No', 0.4),
          _headerCell('Kode', 0.8),
          _headerCell('Nama Cabang', 1.8),
          _headerCell('Jumlah Resi', 1.0, align: pw.TextAlign.right),
          _headerCell('Potensi Valuasi Cabang', 1.2, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      final isEven = i % 2 == 0;
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? PdfColors.grey50 : PdfColors.white,
          ),
          children: [
            _dataCell('${startIndex + i + 1}', 0.4, align: pw.TextAlign.center),
            _dataCell(row['kode_gerai'] as String? ?? '', 0.8),
            _dataCell(row['cabang_name'] as String? ?? '', 1.8),
            _dataCell(_thousands(row['total_resi']), 1.0, align: pw.TextAlign.right),
            _dataCell(row['total_biaya'] != null ? 'Rp ${_thousands(row['total_biaya'])}' : 'Rp 0', 1.2, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    // Total row
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.indigo100),
        children: [
          _dataCell('', 0.4),
          _dataCell('', 0.8),
          _dataCell('TOTAL', 1.8, fontWeight: pw.FontWeight.bold),
          _dataCell(_thousands(totalResi), 1.0, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
          _dataCell('Rp ${_thousands(totalBiaya)}', 1.2, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(0.4),
        1: pw.FlexColumnWidth(0.8),
        2: pw.FlexColumnWidth(2.0),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(1.2),
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
            pw.Text(
              'Dicetak pada: $dateStr',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Dicetak oleh: Super Admin',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _headerCell(String text, double flex, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _dataCell(String text, double flex, {pw.TextAlign align = pw.TextAlign.left, pw.FontWeight? fontWeight}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: fontWeight),
        textAlign: align,
      ),
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
}
