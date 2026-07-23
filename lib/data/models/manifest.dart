import 'transaction.dart';

class Manifest {
  final String id;
  final String noManifest;
  final Map<String, dynamic> createdBy;
  final Map<String, dynamic> driver;
  final Map<String, dynamic> tujuan;
  final String asalCabangId;
  final String asalCabangName;
  final String tipeManifest; // 'antar_cabang' | 'antar_penerima'
  final int workUnit;
  final int totalResi;
  final int jumlahKoli;
  final double totalBerat;
  final String status; // 'dibuat' | 'dalam_perjalanan' | 'selesai'
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated only on detail
  final List<Transaction>? transactions;
  final int? progressSelesai;

  Manifest({
    required this.id,
    required this.noManifest,
    required this.createdBy,
    required this.driver,
    required this.tujuan,
    required this.asalCabangId,
    required this.asalCabangName,
    required this.tipeManifest,
    required this.workUnit,
    required this.totalResi,
    this.jumlahKoli = 0,
    this.totalBerat = 0,
    required this.status,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.transactions,
    this.progressSelesai,
  });

  factory Manifest.fromJson(Map<String, dynamic> json) {
    // Check if transactions are populated (detail endpoint)
    List<Transaction>? txs;
    int? selesai;
    if (json['transactions'] != null) {
      txs = (json['transactions'] as List<dynamic>)
          .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (json['progress'] != null) {
      selesai = (Map<String, dynamic>.from(json['progress'] as Map))['selesai'] as int?;
    }

    return Manifest(
      id: json['_id'] as String,
      noManifest: json['no_manifest'] as String,
      createdBy: Map<String, dynamic>.from(json['created_by'] as Map),
      driver: Map<String, dynamic>.from(json['driver'] as Map),
      tujuan: Map<String, dynamic>.from(json['tujuan'] as Map),
      asalCabangId: json['asal_cabang_id'] as String,
      asalCabangName: json['asal_cabang_name'] as String,
      tipeManifest: json['tipe_manifest'] as String,
      workUnit: json['work_unit'] as int? ?? 0,
      totalResi: json['total_resi'] as int? ?? 0,
      jumlahKoli: json['jumlah_koli'] as int? ?? 0,
      totalBerat: ((json['total_berat'] as num?)?.toDouble() ?? 0),
      status: json['status'] as String? ?? 'dibuat',
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      transactions: txs,
      progressSelesai: selesai,
    );
  }

  String get driverName => driver['name'] as String? ?? '';
  String get driverPhone => driver['phone'] as String? ?? '';
  String get tujuanTipe => tujuan['tipe'] as String? ?? '';
  String get tujuanNama => tujuan['nama'] as String? ?? '';
  double? get tujuanLng {
    final lokasi = tujuan['lokasi'];
    if (lokasi is! Map) return null;
    final coords = lokasi['coordinates'] as List<dynamic>?;
    if (coords != null && coords.length >= 2) return (coords[0] as num).toDouble();
    return null;
  }
  double? get tujuanLat {
    final lokasi = tujuan['lokasi'];
    if (lokasi is! Map) return null;
    final coords = lokasi['coordinates'] as List<dynamic>?;
    if (coords != null && coords.length >= 2) return (coords[1] as num).toDouble();
    return null;
  }
  bool get hasTujuanLokasi => tujuanLat != null && tujuanLng != null;
  String get statusLabel {
    switch (status) {
      case 'dibuat':
        return 'Dibuat';
      case 'dalam_perjalanan':
        return 'Dalam Perjalanan';
      case 'selesai':
        return 'Selesai';
      default:
        return status;
    }
  }

  bool get isAntarCabang => tipeManifest == 'antar_cabang';
  bool get isAntarPenerima => tipeManifest == 'antar_penerima';
  String get tipeLabel => isAntarCabang ? 'Antar Cabang' : 'Antar Penerima';

  int get selesaiCount => progressSelesai ?? 0;

  bool get isComplete => status == 'selesai';
}
