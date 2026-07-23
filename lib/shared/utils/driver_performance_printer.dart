import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'logo_svg_helper.dart';

class DriverPerformancePrinter {
  static Future<void> printReport({
    required int month,
    required int year,
    required List<Map<String, dynamic>> data,
    required String type,
  }) async {
    final logoWidget = await logoSvg(height: 55);

    final doc = pw.Document();
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final monthName = months[month - 1];
    final title = type == 'antar_cabang'
        ? 'LAPORAN DRIVER ANTAR CABANG'
        : 'LAPORAN DRIVER KE PENERIMA';
    const limit = 25;

    final firstBatch = data.sublist(0, data.length > limit ? limit : data.length);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              _buildHeader(logoWidget, title, monthName, year),
              pw.SizedBox(height: 16),
              _buildTable(firstBatch, type),
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
                  _buildHeader(logoWidget, title, monthName, year),
                  pw.SizedBox(height: 16),
                  _buildTable(pageData, type, startIndex: start),
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

  static pw.Widget _buildHeader(pw.Widget logo, String title, String monthName, int year) {
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
                    title,
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

  static pw.Widget _buildTable(List<Map<String, dynamic>> data, String type, {int startIndex = 0}) {
    final totalManifest = data.fold<int>(0, (s, r) => s + ((r['total_manifest'] as num?)?.toInt() ?? 0));
    final totalWorkUnit = data.fold<int>(0, (s, r) => s + ((r['total_work_unit'] as num?)?.toInt() ?? 0));
    final totalResi = data.fold<int>(0, (s, r) => s + ((r['total_resi'] as num?)?.toInt() ?? 0));

    final isAntarCabang = type == 'antar_cabang';

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.indigo700),
        children: [
          _headerCell('No', 0.35),
          _headerCell('Nama Driver', 1.5),
          _headerCell('Total Manifest', 0.9, align: pw.TextAlign.right),
          _headerCell('Total Work Unit', 0.9, align: pw.TextAlign.right, backgroundColor: isAntarCabang ? PdfColors.green700 : null),
          _headerCell('Total Resi', 0.9, align: pw.TextAlign.right, backgroundColor: !isAntarCabang ? PdfColors.green700 : null),
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
            _dataCell('${startIndex + i + 1}', 0.35, align: pw.TextAlign.center),
            _dataCell(row['driver_name'] as String? ?? '-', 1.5),
            _dataCell(_thousands(row['total_manifest']), 0.9, align: pw.TextAlign.right),
            _dataCell(_thousands(row['total_work_unit']), 0.9, align: pw.TextAlign.right),
            _dataCell(_thousands(row['total_resi']), 0.9, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.indigo100),
        children: [
          _dataCell('', 0.35),
          _dataCell('TOTAL', 1.5, fontWeight: pw.FontWeight.bold),
          _dataCell(_thousands(totalManifest), 0.9, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
          _dataCell(_thousands(totalWorkUnit), 0.9, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
          _dataCell(_thousands(totalResi), 0.9, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(0.35),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(0.9),
        3: pw.FlexColumnWidth(0.9),
        4: pw.FlexColumnWidth(0.9),
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
