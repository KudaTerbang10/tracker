import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'logo_svg_helper.dart';

class DriverReportPrinter {
  static Future<void> printReport({
    required int month,
    required int year,
    required List<Map<String, dynamic>> data,
  }) async {
    final logoWidget = await logoSvg(height: 55);

    final doc = pw.Document();
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final monthName = months[month - 1];
    const limit = 25;

    final firstBatch = data.sublist(0, data.length > limit ? limit : data.length);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              _buildHeader(logoWidget, monthName, year),
              pw.SizedBox(height: 16),
              _buildTable(firstBatch),
              pw.SizedBox(height: 12),
              _buildFooter(),
            ],
          );
        },
      ),
    );

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
                  _buildHeader(logoWidget, monthName, year),
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

  static pw.Widget _buildHeader(pw.Widget logo, String monthName, int year) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            logo,
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'YULIS CARGO',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'LAPORAN KERJA DRIVER',
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
    final totalAll = data.fold<int>(0, (s, r) => s + ((r['total'] as num?)?.toInt() ?? 0));
    final totalCabang = data.fold<int>(0, (s, r) => s + ((r['antar_cabang'] as num?)?.toInt() ?? 0));
    final totalPenerima = data.fold<int>(0, (s, r) => s + ((r['antar_penerima'] as num?)?.toInt() ?? 0));

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.indigo700),
        children: [
          _headerCell('No', 0.4),
          _headerCell('Nama Driver', 1.6),
          _headerCell('Total', 0.7, align: pw.TextAlign.right, backgroundColor: PdfColors.green700),
          _headerCell('Antar Cabang', 0.9, align: pw.TextAlign.right),
          _headerCell('Antar Penerima', 1.0, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      final isEven = i % 2 == 0;
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: isEven ? PdfColors.grey50 : PdfColors.white),
          children: [
            _dataCell('${startIndex + i + 1}', 0.4, align: pw.TextAlign.center),
            _dataCell(row['driver_name'] as String? ?? '-', 1.6),
            _dataCell(_thousands(row['total']), 0.7, align: pw.TextAlign.right),
            _dataCell(_thousands(row['antar_cabang']), 0.9, align: pw.TextAlign.right),
            _dataCell(_thousands(row['antar_penerima']), 1.0, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.indigo100),
        children: [
          _dataCell('', 0.4),
          _dataCell('TOTAL', 1.6, fontWeight: pw.FontWeight.bold),
          _dataCell(_thousands(totalAll), 0.7, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
          _dataCell(_thousands(totalCabang), 0.9, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
          _dataCell(_thousands(totalPenerima), 1.0, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(0.4),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(0.7),
        3: pw.FlexColumnWidth(0.9),
        4: pw.FlexColumnWidth(1.0),
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

  static pw.Widget _headerCell(String text, double flex, {pw.TextAlign align = pw.TextAlign.center, PdfColor? backgroundColor}) {
    return pw.Container(
      color: backgroundColor,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: align),
    );
  }

  static pw.Widget _dataCell(String text, double flex, {pw.TextAlign align = pw.TextAlign.left, pw.FontWeight? fontWeight}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8.5, fontWeight: fontWeight), textAlign: align),
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
