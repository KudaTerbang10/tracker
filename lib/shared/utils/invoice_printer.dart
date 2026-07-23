import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/api_constants.dart';
import '../../data/models/transaction.dart';
import 'logo_svg_helper.dart';

class InvoicePrinter {
  static Future<void> printInvoice(
    Transaction tx, {
    String? dicetakOleh,
  }) async {
    final logoWidget = await logoSvg(height: 60);
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('d MMMM yyyy', 'id_ID');
    final now = DateTime.now();

    final jatuhTempo = tx.createdAt.add(Duration(days: tx.tempoHari));
    final isPaid = tx.statusPembayaran == 'paid';
    final accent = PdfColors.green800;

    final pengirimPhone = _formatPhone(tx.pengirim['phone'] as String?);
    final pengirimAddress = tx.pengirim['address'] as String? ?? '-';
    final penerimaPhone = _formatPhone(tx.penerima['phone'] as String?);
    final penerimaAddress = tx.penerimaAddress;
    final asalCabang =
        tx.createdBy['cabang_name']?.toString() ??
        tx.createdBy['konter_name']?.toString() ??
        tx.createdBy['gudang_name']?.toString() ??
        '-';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      logoWidget,
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
                              'SURAT TAGIHAN',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: accent,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'No. Resi: ${tx.noResi}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          color: isPaid
                              ? PdfColors.green100
                              : PdfColors.amber100,
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(4),
                          ),
                          border: pw.Border.all(
                            color: isPaid
                                ? PdfColors.green700
                                : PdfColors.amber700,
                          ),
                        ),
                        child: pw.Text(
                          isPaid ? 'LUNAS' : 'BELUM LUNAS',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: isPaid
                                ? PdfColors.green800
                                : PdfColors.amber900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1.5, color: accent),
                  pw.SizedBox(height: 16),

                  // Info tagihan
                  pw.Row(
                    children: [
                      _infoTile(
                        'Tanggal Transaksi',
                        DateFormat('d MMMM yyyy - HH:mm:ss', 'id_ID')
                            .format(tx.createdAt),
                        flex: 2,
                      ),
                      pw.SizedBox(width: 8),
                      _infoTile(
                        'Jatuh Tempo',
                        dateFmt.format(jatuhTempo),
                        flex: 2,
                      ),
                      pw.SizedBox(width: 8),
                      _infoTile('Cabang Asal', asalCabang, flex: 2),
                    ],
                  ),
                  pw.SizedBox(height: 16),

                  // Pengirim & Penerima
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _partyCard(
                        'PENGIRIM',
                        tx.pengirimName,
                        pengirimPhone,
                        pengirimAddress,
                        PdfColors.blue700,
                        1,
                      ),
                      pw.SizedBox(width: 16),
                      _partyCard(
                        'PENERIMA',
                        tx.penerimaName,
                        penerimaPhone,
                        penerimaAddress,
                        PdfColors.green700,
                        1,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),

                  // Detail paket
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(6),
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.green50,
                            borderRadius: const pw.BorderRadius.vertical(
                              top: pw.Radius.circular(6),
                            ),
                          ),
                          child: pw.Text(
                            'DETAIL PAKET',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900,
                            ),
                          ),
                        ),
                        _detailRow(
                          'Berat',
                          tx.beratLabel.replaceAll('kg', 'Kg'),
                        ),
                        _detailRow(
                          'Jumlah Koli',
                          tx.koliLabel.replaceAll('koli', 'Koli'),
                        ),
                        _detailRow(
                          'Jenis Pengiriman',
                          _capitalize(tx.jenisPembayaran),
                        ),
                        _detailRow(
                          'Status Pengiriman',
                          StatusList.label(tx.statusSaatIni),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // Total
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Expanded(child: pw.Container()),
                      pw.Container(
                        width: 240,
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green50,
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(6),
                          ),
                          border: pw.Border.all(color: PdfColors.green300),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'Total Tagihan',
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    color: PdfColors.grey800,
                                  ),
                                ),
                                pw.Text(
                                  currencyFmt.format(tx.biayaKirim),
                                  style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.green900,
                                  ),
                                ),
                              ],
                            ),
                            if (isPaid &&
                                tx.pembayaranDikonfirmasiPada != null) ...[
                              pw.SizedBox(height: 6),
                              pw.Divider(color: PdfColors.green300),
                              pw.SizedBox(height: 4),
                              pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    'Dibayar pada',
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      color: PdfColors.grey800,
                                    ),
                                  ),
                                  pw.Text(
                                    dateFmt.format(
                                      tx.pembayaranDikonfirmasiPada!,
                                    ),
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.green900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.Spacer(),
                  pw.Divider(thickness: 0.5),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Dicetak pada: ${dateFmt.format(now)}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        'Dicetak oleh: ${dicetakOleh ?? '-'}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        'YULIS CARGO - ${tx.noResi}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
        return doc.save();
      },
    );
  }

  static String _formatPhone(dynamic phone) {
    if (phone == null) return '-';
    final raw = phone.toString().replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) return '-';
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('-');
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  static pw.Widget _infoTile(
    String label,
    String value, {
    required int flex,
  }) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 10,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: const pw.BorderRadius.vertical(
                  top: pw.Radius.circular(6),
                ),
              ),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 10,
              ),
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _partyCard(
    String title,
    String name,
    String phone,
    String address,
    PdfColor accent,
    int flex,
  ) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 12,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.vertical(
                  top: pw.Radius.circular(6),
                ),
              ),
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    name,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Telp: $phone',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    address,
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _detailRow(String label, String value) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
