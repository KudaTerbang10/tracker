import 'dart:async';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/utils/datetime_utils.dart';
import '../../../data/models/manifest.dart';
import '../../../data/models/transaction.dart';

pw.Font? _cachedHiraFont;

Future<pw.Font> _getHiraFont() async {
  if (_cachedHiraFont != null) return _cachedHiraFont!;
  final data = await rootBundle.load('assets/pics/hiralogo.ttf');
  _cachedHiraFont = pw.Font.ttf(data);
  return _cachedHiraFont!;
}

Future<void> printManifestA4(Manifest m) async {
  final txs = m.transactions ?? <Transaction>[];
  final fmtDate = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');
  final now = fmtDate.format(toJakarta(DateTime.now()));

  final hiraFont = await _getHiraFont();

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              String.fromCharCode(0xe000),
              style: pw.TextStyle(
                font: hiraFont,
                fontSize: 60,
                color: PdfColors.red,
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
                    'MANIFEST PENGIRIMAN',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    m.noManifest,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      fontFallback: [pw.Font.courier()],
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Dicetak: $now',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: m.noManifest,
              width: 240,
              height: 50,
            ),
          ],
        ),
        pw.Divider(height: 24, thickness: 1),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfLabel('Asal', m.asalCabangName),
                  pw.SizedBox(height: 4),
                  _pdfLabel('Tujuan', m.tujuanNama),
                  pw.SizedBox(height: 4),
                  _pdfLabel('Tipe', m.tipeLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfLabel('Driver', m.driverName),
                  pw.SizedBox(height: 4),
                  _pdfLabel('Kontak', m.driverPhone),
                  pw.SizedBox(height: 4),
                  _pdfLabel('Work Unit', '${m.workUnit}'),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: m.noManifest,
              width: 55,
              height: 55,
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FixedColumnWidth(120),
            2: const pw.FixedColumnWidth(95),
            3: const pw.FixedColumnWidth(95),
            4: const pw.FixedColumnWidth(45),
            5: const pw.FixedColumnWidth(35),
            6: const pw.FixedColumnWidth(60),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _pdfCell('No', header: true),
                _pdfCell('No. Resi', header: true),
                _pdfCell('Pengirim', header: true),
                _pdfCell('Penerima', header: true),
                _pdfCell('Berat', header: true),
                _pdfCell('Koli', header: true),
                _pdfCell('COD', header: true),
              ],
            ),
            ...txs.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final tx = entry.value;
              return pw.TableRow(
                children: [
                  _pdfCell('$i'),
                  _pdfCell(tx.noResi, font: pw.Font.courier()),
                  _pdfCell(tx.pengirimName),
                  _pdfCell(tx.penerimaName),
                  _pdfCell(tx.beratLabel),
                  _pdfCell(tx.koliLabel),
                  _pdfCell(tx.codLabel),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 16),

        pw.Row(
          children: [
            _pdfLabel('Total Resi: ${txs.length}'),
            pw.SizedBox(width: 24),
            _pdfLabel(
              'Total Berat: ${txs.fold(0.0, (sum, tx) => sum + (tx.paket['berat_kg'] as num? ?? 0).toDouble()).toStringAsFixed(1)} kg',
            ),
            pw.SizedBox(width: 24),
            _pdfLabel(
              'Total Koli: ${txs.fold(0, (sum, tx) => sum + (tx.paket['jumlah_koli'] as num? ?? 0).toInt())}',
            ),
            pw.SizedBox(width: 24),
            _pdfLabel(
              'Total COD: ${Transaction.formatThousands(txs.fold(0.0, (sum, tx) => sum + tx.codNominal))}',
            ),
          ],
        ),
        pw.SizedBox(height: 32),

        if (m.isAntarCabang)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text(
                    'Admin ${m.asalCabangName}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 32),
                  pw.Text(
                    '(_______________)',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Driver', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 32),
                  pw.Text(
                    '(_______________)',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text(
                    'Admin ${m.tujuanNama}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 32),
                  pw.Text(
                    '(_______________)',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          )
        else
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text(
                    'Admin ${m.asalCabangName}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 32),
                  pw.Text(
                    '(_______________)',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(width: 80),
              pw.Column(
                children: [
                  pw.Text('Driver', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 32),
                  pw.Text(
                    '(_______________)',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
      ],
    ),
  );

  final bytes = await pdf.save();
  await Printing.layoutPdf(onLayout: (_) => bytes);
}

Future<void> printManifest80mm(Manifest m) async {
  final txs = m.transactions ?? <Transaction>[];
  final fmtDate = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');
  final tglBuat = fmtDate.format(toJakarta(m.createdAt));
  final tglCetak = fmtDate.format(toJakarta(DateTime.now()));

  final hiraFont = await _getHiraFont();

  final totalBerat = txs.fold(
    0.0,
    (sum, tx) => sum + (tx.paket['berat_kg'] as num? ?? 0).toDouble(),
  );
  final totalKoli = txs.fold(
    0,
    (sum, tx) => sum + (tx.paket['jumlah_koli'] as num? ?? 0).toInt(),
  );

  const pageFmt = PdfPageFormat(78 * PdfPageFormat.mm, 100 * PdfPageFormat.mm);
  const margin = pw.EdgeInsets.all(6);

  final totalCod = txs.fold(0.0, (sum, tx) => sum + tx.codNominal);

  pw.Widget header() {
    const s = pw.TextStyle(fontSize: 6);
    final lbl = pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              String.fromCharCode(0xe000),
              style: pw.TextStyle(
                font: hiraFont,
                fontSize: 16,
                color: PdfColors.red,
              ),
            ),
            pw.Expanded(child: pw.SizedBox()),
            pw.Text(
              'MANIFEST PENGIRIMAN',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.BarcodeWidget(
          barcode: pw.Barcode.code128(),
          data: m.noManifest,
          width: 150,
          height: 40,
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Dibuat', style: lbl),
                pw.Text('Cetak', style: lbl),
                pw.Text('Asal', style: lbl),
                pw.Text('Tujuan', style: lbl),
                pw.Text('Driver', style: lbl),
                if (m.driverPhone.isNotEmpty) pw.Text('Kontak', style: lbl),
              ],
            ),
            pw.SizedBox(width: 4),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(tglBuat, style: s),
                pw.Text(tglCetak, style: s),
                pw.Text(m.asalCabangName, style: s),
                pw.Text(m.tujuanNama, style: s),
                pw.Text(m.driverName, style: s),
                if (m.driverPhone.isNotEmpty) pw.Text(m.driverPhone, style: s),
              ],
            ),
            pw.Expanded(child: pw.SizedBox()),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: m.noManifest,
              width: 38,
              height: 38,
            ),
          ],
        ),
        pw.Divider(thickness: 0.5),
        pw.Center(
          child: pw.Text(
            'DAFTAR RESI',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 2),
      ],
    );
  }

  pw.Widget card(int i, Transaction tx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 2),
      padding: const pw.EdgeInsets.all(2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                '$i.',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 3),
              pw.Expanded(
                child: pw.Text(
                  tx.noResi,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    fontFallback: [pw.Font.courier()],
                  ),
                ),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Pengirim: ${tx.pengirimName}',
                  style: const pw.TextStyle(fontSize: 6),
                ),
              ),
              pw.Text(
                tx.beratLabel,
                style: pw.TextStyle(
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 3),
              pw.Text(
                tx.koliLabel,
                style: pw.TextStyle(
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (tx.jenisPembayaran == 'cod') ...[
                pw.SizedBox(width: 3),
                pw.Text(
                  'COD: ${tx.codLabel}',
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          pw.Text(
            'Penerima: ${tx.penerimaName}',
            style: const pw.TextStyle(fontSize: 6),
          ),
          if (tx.penerimaAddress.isNotEmpty)
            pw.Text(tx.penerimaAddress, style: const pw.TextStyle(fontSize: 6)),
        ],
      ),
    );
  }

  pw.Widget summary() {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'Total Resi: ${txs.length}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(width: 6),
            pw.Text(
              'Total Berat: ${totalBerat.toStringAsFixed(1)} kg',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'Total Koli: $totalKoli',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(width: 6),
            pw.Text(
              'Total COD: ${Transaction.formatThousands(totalCod)}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget sig() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Center(child: _ttdRow('Admin ${m.asalCabangName}')),
        pw.SizedBox(height: 14),
        pw.Center(child: _ttdRow('Driver')),
        if (m.isAntarCabang) ...[
          pw.SizedBox(height: 14),
          pw.Center(child: _ttdRow('Admin ${m.tujuanNama}')),
        ],
      ],
    );
  }

  final cards = txs
      .asMap()
      .entries
      .map((e) => card(e.key + 1, e.value))
      .toList();
  final allPages = <pw.Widget>[];

  if (cards.isEmpty) {
    allPages.add(pw.Column(children: [header(), summary(), sig()]));
  } else {
    int idx = 0;
    final first = <pw.Widget>[header()];
    for (int i = 0; i < 3 && idx < cards.length; i++, idx++) {
      first.add(cards[idx]);
    }
    allPages.add(pw.Column(children: first));

    while (idx + 5 <= cards.length) {
      final middle = <pw.Widget>[];
      for (int i = 0; i < 5; i++, idx++) {
        middle.add(cards[idx]);
      }
      allPages.add(pw.Column(children: middle));
    }

    final last = <pw.Widget>[];
    while (idx < cards.length) {
      last.add(cards[idx++]);
    }
    last.addAll([summary(), sig()]);
    allPages.add(pw.Column(children: last));
  }

  final pdf = pw.Document();
  for (int i = allPages.length - 1; i >= 0; i--) {
    pdf.addPage(
      pw.Page(
        pageFormat: pageFmt,
        margin: margin,
        build: (_) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          child: allPages[i],
        ),
      ),
    );
  }

  final bytes80 = await pdf.save();
  await Printing.layoutPdf(onLayout: (_) => bytes80);
}

pw.Widget _pdfLabel(String label, [String? value]) {
  return pw.Text(
    value != null ? '$label: $value' : label,
    style: const pw.TextStyle(fontSize: 10),
  );
}

pw.Widget _pdfCell(String text, {bool header = false, pw.Font? font}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: header ? 9 : 8,
        fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _ttdRow(String title) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text(
        title,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 28),
      pw.Text('(_______________)', style: const pw.TextStyle(fontSize: 9)),
    ],
  );
}
