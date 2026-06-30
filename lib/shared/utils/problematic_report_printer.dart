import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class ProblematicReportPrinter {
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
  }) async {
    final hiraFont = await _getHiraFont();
    final isHilang = jenis == 'hilang';
    final title = isHilang ? 'LAPORAN BARANG HILANG' : 'LAPORAN GAGAL KIRIM';
    final accentColor = isHilang ? PdfColors.red700 : PdfColors.amber700;
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final monthName = months[month - 1];

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
                  _buildHeader(hiraFont, title, monthName, year, accentColor),
                  pw.SizedBox(height: 16),
                  _buildTable(data, isHilang: isHilang),
                  pw.SizedBox(height: 12),
                  _buildFooter(),
                ],
              );
            },
          ),
        );

        if (data.length > 20) {
          for (var page = 1; page * 20 < data.length; page++) {
            final start = page * 20;
            final end = start + 20 > data.length ? data.length : start + 20;
            final pageData = data.sublist(start, end);

            doc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(24),
                build: (pw.Context context) {
                  return pw.Column(
                    children: [
                      _buildHeader(hiraFont, title, monthName, year, accentColor),
                      pw.SizedBox(height: 16),
                      _buildTable(pageData, startIndex: start, isHilang: isHilang),
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

  static pw.Widget _buildHeader(pw.Font hiraFont, String title, String monthName, int year, PdfColor dividerColor) {
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
        pw.Divider(thickness: 1.5, color: dividerColor),
      ],
    );
  }

  static pw.Widget _buildTable(List<Map<String, dynamic>> data, {int startIndex = 0, bool isHilang = true}) {
    if (isHilang) {
      return _buildHilangTable(data, startIndex: startIndex);
    }
    return _buildGagalKirimTable(data, startIndex: startIndex);
  }

  static pw.Widget _buildGagalKirimTable(List<Map<String, dynamic>> data, {int startIndex = 0}) {
    final totalSelesai = data.where((r) => r['status'] == 'kasus_selesai').length;

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.amber800),
        children: [
          _headerCell('No', 0.4),
          _headerCell('No. Resi', 1.8),
          _headerCell('Cabang', 1.5),
          _headerCell('Tgl Laporan', 1.0),
          _headerCell('Status', 0.8),
          _headerCell('Deskripsi', 2.8),
        ],
      ),
    ];

    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      final isEven = i % 2 == 0;
      final status = row['status'] as String? ?? '';
      final dateStr = row['dilaporkan_pada'] != null
          ? DateFormat('dd MMM yyyy', 'id_ID')
              .format(DateTime.parse(row['dilaporkan_pada'] as String).toLocal())
          : '-';
      final statusLabel = status == 'kasus_selesai' ? 'Selesai' : 'Proses';
      final catatan = row['catatan'] as String? ?? '-';

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: isEven ? PdfColors.grey50 : PdfColors.white),
          children: [
            _dataCell('${startIndex + i + 1}', 0.4, align: pw.TextAlign.center),
            _dataCell(row['no_resi'] as String? ?? '-', 1.8),
            _dataCell(row['cabang'] as String? ?? '-', 1.5),
            _dataCell(dateStr, 1.0, align: pw.TextAlign.center),
            _dataCell(statusLabel, 0.8, align: pw.TextAlign.center),
            _dataCell(catatan, 2.8),
          ],
        ),
      );
    }

    final summaryColor = PdfColors.amber100;
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: summaryColor),
        children: [
          _dataCell('', 0.4),
          _dataCell('TOTAL', 1.8, fontWeight: pw.FontWeight.bold),
          _dataCell('${data.length} resi', 1.5, fontWeight: pw.FontWeight.bold),
          _dataCell('', 1.0),
          _dataCell('$totalSelesai selesai', 0.8, align: pw.TextAlign.center, fontWeight: pw.FontWeight.bold),
          _dataCell('', 2.8),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(0.4),
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(0.8),
        5: pw.FlexColumnWidth(2.8),
      },
      children: rows,
    );
  }

  static pw.Widget _buildHilangTable(List<Map<String, dynamic>> data, {int startIndex = 0}) {
    final totalSelesai = data.where((r) => r['status'] == 'kasus_selesai').length;

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.red700),
        children: [
          _headerCell('No', 0.4),
          _headerCell('No. Resi', 1.8),
          _headerCell('Cabang', 1.5),
          _headerCell('Tgl Laporan', 1.0),
          _headerCell('Status', 0.8),
          _headerCell('Deskripsi', 2.8),
        ],
      ),
    ];

    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      final isEven = i % 2 == 0;
      final status = row['status'] as String? ?? '';
      final dateStr = row['dilaporkan_pada'] != null
          ? DateFormat('dd MMM yyyy', 'id_ID')
              .format(DateTime.parse(row['dilaporkan_pada'] as String).toLocal())
          : '-';
      final statusLabel = status == 'kasus_selesai' ? 'Selesai' : 'Proses';
      final catatan = row['catatan'] as String? ?? '-';

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: isEven ? PdfColors.grey50 : PdfColors.white),
          children: [
            _dataCell('${startIndex + i + 1}', 0.4, align: pw.TextAlign.center),
            _dataCell(row['no_resi'] as String? ?? '-', 1.8),
            _dataCell(row['cabang'] as String? ?? '-', 1.5),
            _dataCell(dateStr, 1.0, align: pw.TextAlign.center),
            _dataCell(statusLabel, 0.8, align: pw.TextAlign.center),
            _dataCell(catatan, 2.8),
          ],
        ),
      );
    }

    final summaryColor = PdfColors.red100;
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: summaryColor),
        children: [
          _dataCell('', 0.4),
          _dataCell('TOTAL', 1.8, fontWeight: pw.FontWeight.bold),
          _dataCell('${data.length} resi', 1.5, fontWeight: pw.FontWeight.bold),
          _dataCell('', 1.0),
          _dataCell('$totalSelesai selesai', 0.8, align: pw.TextAlign.center, fontWeight: pw.FontWeight.bold),
          _dataCell('', 2.8),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(0.4),
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(0.8),
        5: pw.FlexColumnWidth(2.8),
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

  static pw.Widget _dataCell(String text, double flex, {pw.TextAlign align = pw.TextAlign.left, pw.FontWeight? fontWeight}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 7.5, fontWeight: fontWeight), textAlign: align),
    );
  }
}
