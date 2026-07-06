import 'tracking_log.dart';

class Transaction {
  final String id;
  final String noResi;
  final String kodeGerai;
  final String barcodeData;
  final Map<String, dynamic> pengirim;
  final Map<String, dynamic> penerima;
  final Map<String, dynamic> paket;
  final Map<String, dynamic> createdBy;
  final String statusSaatIni;
  final String? namaDriver;
  final String? kontakDriver;
  final String? driverUserId;
  final String? noManifest;
  final Map<String, dynamic>? tujuanSelanjutnya;
  final String? namaPenerimaAkhir;
  final String? currentCabangId;
  final Map<String, dynamic>? lokasiPenerima;
  final String? jenisMasalah;
  final String? catatanMasalah;
  final Map<String, dynamic>? dilaporkanOleh;
  final DateTime? dilaporkanPada;
  final Map<String, dynamic>? diselesaikanOleh;
  final DateTime? diselesaikanPada;
  final String jenisPembayaran;
  final String statusPembayaran;
  final int tempoHari;
  final Map<String, dynamic>? pembayaranDikonfirmasiOleh;
  final DateTime? pembayaranDikonfirmasiPada;
  final String? codCabangId;
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
    required this.createdBy,
    required this.statusSaatIni,
    this.namaDriver,
    this.kontakDriver,
    this.driverUserId,
    this.noManifest,
    this.tujuanSelanjutnya,
    this.namaPenerimaAkhir,
    this.currentCabangId,
    this.lokasiPenerima,
    this.jenisMasalah,
    this.catatanMasalah,
    this.dilaporkanOleh,
    this.dilaporkanPada,
    this.diselesaikanOleh,
    this.diselesaikanPada,
    this.jenisPembayaran = 'cash',
    this.statusPembayaran = 'paid',
    this.tempoHari = 14,
    this.pembayaranDikonfirmasiOleh,
    this.pembayaranDikonfirmasiPada,
    this.codCabangId,
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
    createdBy: Map<String, dynamic>.from(json['created_by'] as Map),
    statusSaatIni: json['status_saat_ini'] as String,
    namaDriver: json['nama_driver'] as String?,
    kontakDriver: json['kontak_driver'] as String?,
    driverUserId: json['driver_user_id'] as String?,
    noManifest: json['no_manifest'] as String?,
    tujuanSelanjutnya: json['tujuan_selanjutnya'] as Map<String, dynamic>?,
    namaPenerimaAkhir: json['nama_penerima_akhir'] as String?,
    currentCabangId: json['current_cabang_id'] as String?,
    lokasiPenerima: json['lokasi_penerima'] as Map<String, dynamic>?,
    jenisMasalah: json['jenis_masalah'] as String?,
    catatanMasalah: json['catatan_masalah'] as String?,
    dilaporkanOleh: json['dilaporkan_oleh'] as Map<String, dynamic>?,
    dilaporkanPada: json['dilaporkan_pada'] != null ? DateTime.parse(json['dilaporkan_pada'] as String) : null,
    diselesaikanOleh: json['diselesaikan_oleh'] as Map<String, dynamic>?,
    diselesaikanPada: json['diselesaikan_pada'] != null ? DateTime.parse(json['diselesaikan_pada'] as String) : null,
    jenisPembayaran: json['jenis_pembayaran'] as String? ?? 'cash',
    statusPembayaran: json['status_pembayaran'] as String? ?? 'paid',
    tempoHari: json['tempo_hari'] as int? ?? 14,
    pembayaranDikonfirmasiOleh: json['pembayaran_dikonfirmasi_oleh'] as Map<String, dynamic>?,
    pembayaranDikonfirmasiPada: json['pembayaran_dikonfirmasi_pada'] != null ? DateTime.parse(json['pembayaran_dikonfirmasi_pada'] as String) : null,
    codCabangId: json['cod_cabang_id'] as String?,
    trackingLogs: (json['tracking_logs'] as List<dynamic>?)
        ?.map((e) => TrackingLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList() ?? [],
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  String get pengirimName => pengirim['name'] as String? ?? '';
  String get penerimaName => penerima['name'] as String? ?? '';
  String get penerimaAddress => penerima['address'] as String? ?? '';
  double? get penerimaLatitude {
    final coords = lokasiPenerima?['coordinates'] as List<dynamic>?;
    if (coords != null && coords.length >= 2) return (coords[1] as num).toDouble();
    return null;
  }
  double? get penerimaLongitude {
    final coords = lokasiPenerima?['coordinates'] as List<dynamic>?;
    if (coords != null && coords.length >= 2) return (coords[0] as num).toDouble();
    return null;
  }
  String get beratLabel => '${paket['berat_kg']?.toStringAsFixed(1) ?? '0'} kg';
  String get koliLabel => '${paket['jumlah_koli'] ?? '0'} koli';
  int get jumlahKoli => (paket['jumlah_koli'] as num?)?.toInt() ?? 0;
  double get biayaKirim => (paket['biaya_kirim'] as num?)?.toDouble() ?? 0;

  /// Nama cabang tempat paket diterima (dari tracking log terakhir status diterima_cabang)
  String get diterimaDiCabang {
    if (statusSaatIni != 'diterima_cabang') return '';
    for (final log in trackingLogs.reversed) {
      if (log.status == 'diterima_cabang') {
        final nama = log.lokasiName;
        if (nama.isNotEmpty) return nama;
        return log.tujuan?['nama'] as String? ?? '';
      }
    }
    return '';
  }
}
