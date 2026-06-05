import 'tracking_log.dart';

class Transaction {
  final String id;
  final String noResi;
  final String kodeGerai;
  final String barcodeData;
  final Map<String, dynamic> pengirim;
  final Map<String, dynamic> penerima;
  final Map<String, dynamic> paket;
  final Map<String, dynamic> adminKonter;
  final String statusSaatIni;
  final String? namaDriver;
  final String? kontakDriver;
  final String? driverUserId;
  final Map<String, dynamic>? tujuanSelanjutnya;
  final String? namaPenerimaAkhir;
  final List<TrackingLog> trackingLogs;
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.noResi,
    required this.kodeGerai,
    required this.barcodeData,
    required this.pengirim,
    required this.penerima,
    required this.paket,
    required this.adminKonter,
    required this.statusSaatIni,
    this.namaDriver,
    this.kontakDriver,
    this.driverUserId,
    this.tujuanSelanjutnya,
    this.namaPenerimaAkhir,
    required this.trackingLogs,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['_id'] as String,
    noResi: json['no_resi'] as String,
    kodeGerai: json['kode_gerai'] as String,
    barcodeData: json['barcode_data'] as String,
    pengirim: Map<String, dynamic>.from(json['pengirim'] as Map),
    penerima: Map<String, dynamic>.from(json['penerima'] as Map),
    paket: Map<String, dynamic>.from(json['paket'] as Map),
    adminKonter: Map<String, dynamic>.from(json['admin_konter'] as Map),
    statusSaatIni: json['status_saat_ini'] as String,
    namaDriver: json['nama_driver'] as String?,
    kontakDriver: json['kontak_driver'] as String?,
    driverUserId: json['driver_user_id'] as String?,
    tujuanSelanjutnya: json['tujuan_selanjutnya'] as Map<String, dynamic>?,
    namaPenerimaAkhir: json['nama_penerima_akhir'] as String?,
    trackingLogs: (json['tracking_logs'] as List<dynamic>?)
        ?.map((e) => TrackingLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList() ?? [],
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  String get pengirimName => pengirim['name'] as String? ?? '';
  String get penerimaName => penerima['name'] as String? ?? '';
  String get penerimaAddress => penerima['address'] as String? ?? '';
  String get beratLabel => '${paket['berat_kg']?.toStringAsFixed(1) ?? '0'} kg';
  String get koliLabel => '${paket['jumlah_koli'] ?? '0'} koli';
  int get jumlahKoli => (paket['jumlah_koli'] as num?)?.toInt() ?? 0;
  double get biayaKirim => (paket['biaya_kirim'] as num?)?.toDouble() ?? 0;
}
