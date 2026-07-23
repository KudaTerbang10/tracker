import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'logo_svg_helper.dart';

class PaymentReportPrinter {
  static Future<void> printReport({
    required int month,
    required int year,
    required List<Map<String, dynamic>> data,
    required String jenis,
    String? cabangName,
  }) async {
    final logoWidget = await logoSvg(height: 55);
    final isCOD = jenis == 'cod';
    final title = isCOD
        ? 'LAPORAN COD'
        : (cabangName != null && cabangName.isNotEmpty
            ? 'LAPORAN TEMPO'
            : 'LAPORAN TEMPO SEMUA CABANG');
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final monthName = months[month - 1];
    final headerColor = isCOD ? PdfColors.amber800 : PdfColors.green800;

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();
        const limit = 25;

        // Page 1: first 25 rows (same pattern as printRekonsiliasiReport)
        final firstBatch = data.sublist(0, data.length > limit ? limit : data.length);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  _buildHeader(logoWidget, title, monthName, year, headerColor, cabangName),
                  if (!isCOD) ...[
                    pw.SizedBox(height: 10),
                    _buildTempoSummaryWidget(data),
                    pw.SizedBox(height: 12),
                  ] else
                    pw.SizedBox(height: 16),
                  _buildTable(firstBatch, startIndex: 0, isCOD: isCOD),
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
                      _buildHeader(logoWidget, title, monthName, year, headerColor, cabangName),
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

  static pw.Widget _buildHeader(pw.Widget logo, String title, String monthName, int year, PdfColor accentColor, String? cabangName) {
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
    final dateFmt = DateFormat('dd/MM/yyyy');

    final totalLunas = data.where((r) => r['status_pembayaran'] == 'paid').length;
    final totalNominal = data.fold<int>(0, (sum, r) => sum + ((r['biaya_kirim'] as num?)?.toInt() ?? 0));

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: headerColor),
        children: [
          _headerCell('No', 0.3),
          _headerCell('No. Resi', 1.8),
          _headerCell(isCOD ? 'Pengirim' : 'Nama Cabang', 1.6),
          _headerCell(isCOD ? 'Penerima' : 'Jatuh Tempo', 1.6),
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

      String col3, col4;
      if (isCOD) {
        col3 = row['pengirim'] as String? ?? '-';
        col4 = row['penerima'] as String? ?? '-';
      } else {
        col3 = row['cabang_name'] as String? ?? '-';
        final jatuh = row['jatuh_tempo'] as DateTime?;
        col4 = jatuh != null ? dateFmt.format(jatuh) : '-';
      }

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: isEven ? PdfColors.grey50 : PdfColors.white),
          children: [
            _dataCell('${startIndex + i + 1}', 0.3, align: pw.TextAlign.center),
            _dataCell(row['no_resi'] as String? ?? '-', 1.8),
            _dataCell(col3, 1.6),
            _dataCell(col4, 1.6, align: isCOD ? pw.TextAlign.left : pw.TextAlign.center),
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

  static pw.Widget _headerCell(String text, double flex, {pw.TextAlign align = pw.TextAlign.center, PdfColor? backgroundColor}) {
    return pw.Container(
      color: backgroundColor,
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

  static num _numVal(Map<String, dynamic> m, String key) {
    final v = m[key];
    return v is num ? v : 0;
  }

  static pw.Widget _buildTempoSummaryWidget(List<Map<String, dynamic>> data) {
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final totalNominal = data.fold<int>(0, (s, r) => s + ((r['biaya_kirim'] as num?)?.toInt() ?? 0));
    final totalLunas = data
        .where((r) => r['status_pembayaran'] == 'paid')
        .fold<int>(0, (s, r) => s + ((r['biaya_kirim'] as num?)?.toInt() ?? 0));
    final totalBelumLunas = totalNominal - totalLunas;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Row(
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Total Nominal Tempo', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text(currencyFmt.format(totalNominal), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
            ],
          ),
          pw.SizedBox(width: 28),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Total Lunas', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text(currencyFmt.format(totalLunas), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
            ],
          ),
          pw.SizedBox(width: 28),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Total Belum Lunas', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text(currencyFmt.format(totalBelumLunas), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLegend() {
    final colorCash = PdfColor.fromInt(0xFF10B981);
    final colorCod = PdfColor.fromInt(0xFF6366F1);
    final colorTempo = PdfColor.fromInt(0xFFF59E0B);

    return pw.Row(
      children: [
        _buildLegendItem('Cash', colorCash),
        pw.SizedBox(width: 14),
        _buildLegendItem('COD (Last Mile + Retur)', colorCod),
        pw.SizedBox(width: 14),
        _buildLegendItem('Tempo (Lunas)', colorTempo),
      ],
    );
  }

  static pw.Widget _buildLegendWithSummary(num totalCash, num totalCod, num totalTempo, num totalAll) {
    final colorCash = PdfColor.fromInt(0xFF10B981);
    final colorCod = PdfColor.fromInt(0xFF6366F1);
    final colorTempo = PdfColor.fromInt(0xFFF59E0B);
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        children: [
          _buildLegendItem('Cash', colorCash),
          pw.SizedBox(width: 6),
          pw.Text(currencyFmt.format(totalCash), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: colorCash)),
          pw.SizedBox(width: 12),
          _buildLegendItem('COD', colorCod),
          pw.SizedBox(width: 6),
          pw.Text(currencyFmt.format(totalCod), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: colorCod)),
          pw.SizedBox(width: 12),
          _buildLegendItem('Tempo', colorTempo),
          pw.SizedBox(width: 6),
          pw.Text(currencyFmt.format(totalTempo), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: colorTempo)),
          pw.SizedBox(width: 16),
          pw.Container(width: 1, height: 16, color: PdfColors.grey300),
          pw.SizedBox(width: 12),
          pw.Text('Total Nasional:', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(width: 4),
          pw.Text(currencyFmt.format(totalAll), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
        ],
      ),
    );
  }

  static pw.Widget _buildLegendItem(String label, PdfColor color) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 8,
          height: 8,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildRekonsiliasiTable(List<Map<String, dynamic>> data, {int startIndex = 0}) {
    final headerColor = PdfColors.indigo800;
    final summaryColor = PdfColors.indigo100;
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    num totalCash = 0;
    num totalCod = 0;
    num totalTempo = 0;
    num totalAll = 0;
    for (final row in data) {
      totalCash += _numVal(row, 'cash');
      totalCod += _numVal(row, 'cod_total');
      totalTempo += _numVal(row, 'tempo');
      totalAll += _numVal(row, 'total');
    }

    final colorCash = PdfColor.fromInt(0xFF10B981);
    final colorCod = PdfColor.fromInt(0xFF6366F1);
    final colorTempo = PdfColor.fromInt(0xFFF59E0B);

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: headerColor),
        children: [
          _headerCell('No', 0.3),
          _headerCell('Nama Cabang', 1.8, align: pw.TextAlign.left),
          _headerCell('Cash', 1.2, align: pw.TextAlign.right, backgroundColor: colorCash),
          _headerCell('COD', 1.2, align: pw.TextAlign.right, backgroundColor: colorCod),
          _headerCell('Tempo', 1.2, align: pw.TextAlign.right, backgroundColor: colorTempo),
          _headerCell('Total', 1.3, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      final isEven = i % 2 == 0;
      final nama = (row['nama_cabang'] as String?) ?? (row['kode_cabang'] as String?) ?? '-';
      final cash = _numVal(row, 'cash');
      final cod = _numVal(row, 'cod_total');
      final tempo = _numVal(row, 'tempo');
      final total = _numVal(row, 'total');

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: isEven ? PdfColors.grey50 : PdfColors.white),
          children: [
            _dataCell('${startIndex + i + 1}', 0.3, align: pw.TextAlign.center),
            _dataCell(nama, 1.8),
            _dataCell(currencyFmt.format(cash), 1.2, align: pw.TextAlign.right),
            _dataCell(currencyFmt.format(cod), 1.2, align: pw.TextAlign.right),
            _dataCell(currencyFmt.format(tempo), 1.2, align: pw.TextAlign.right),
            _dataCell(currencyFmt.format(total), 1.3, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
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
          _dataCell(currencyFmt.format(totalCash), 1.2, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
          _dataCell(currencyFmt.format(totalCod), 1.2, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
          _dataCell(currencyFmt.format(totalTempo), 1.2, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
          _dataCell(currencyFmt.format(totalAll), 1.3, align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.3),
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.3),
      },
      children: rows,
    );
  }

  static Future<void> printRekonsiliasiReport({
    required int month,
    required int year,
    required List<Map<String, dynamic>> data,
  }) async {
    final logoWidget = await logoSvg(height: 55);
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final monthName = months[month - 1];
    final accentColor = PdfColors.indigo700;

    // Hitung total nasional dari data
    num totalCash = 0, totalCod = 0, totalTempo = 0, totalAll = 0;
    for (final row in data) {
      totalCash += _numVal(row, 'cash');
      totalCod += _numVal(row, 'cod_total');
      totalTempo += _numVal(row, 'tempo');
      totalAll += _numVal(row, 'total');
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();
        
        final hasPagination = data.length > 25;
        final listLimit = hasPagination ? 25 : data.length;
        
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(logoWidget, 'REKONSILIASI SETORAN PER CABANG', monthName, year, accentColor, null),
                  pw.SizedBox(height: 10),
                  _buildLegendWithSummary(totalCash, totalCod, totalTempo, totalAll),
                  pw.SizedBox(height: 12),
                  _buildRekonsiliasiTable(data.sublist(0, listLimit)),
                  pw.SizedBox(height: 16),
                  _buildFooter(),
                ],
              );
            },
          ),
        );

        if (hasPagination) {
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
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildHeader(logoWidget, 'REKONSILIASI SETORAN PER CABANG', monthName, year, accentColor, null),
                      pw.SizedBox(height: 12),
                      _buildLegend(),
                      pw.SizedBox(height: 12),
                      _buildRekonsiliasiTable(pageData, startIndex: start),
                      pw.SizedBox(height: 16),
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
}
