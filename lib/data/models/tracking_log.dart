class TrackingLog {
  final String status;
  final String deskripsi;
  final Map<String, dynamic> pelaku;
  final Map<String, dynamic>? lokasi;
  final Map<String, dynamic>? driverDitugaskan;
  final Map<String, dynamic>? tujuan;
  final String? namaPenerima;
  final DateTime timestamp;

  TrackingLog({
    required this.status,
    required this.deskripsi,
    required this.pelaku,
    this.lokasi,
    this.driverDitugaskan,
    this.tujuan,
    this.namaPenerima,
    required this.timestamp,
  });

  factory TrackingLog.fromJson(Map<String, dynamic> json) => TrackingLog(
    status: json['status'] as String,
    deskripsi: json['deskripsi'] as String? ?? '',
    pelaku: Map<String, dynamic>.from(json['pelaku'] as Map),
    lokasi: json['lokasi'] as Map<String, dynamic>?,
    driverDitugaskan: json['driver_ditugaskan'] as Map<String, dynamic>?,
    tujuan: json['tujuan'] as Map<String, dynamic>?,
    namaPenerima: json['nama_penerima'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  String get pelakuName => pelaku['name'] as String? ?? '';
  String get pelakuRole => pelaku['role'] as String? ?? '';
  String get lokasiName => lokasi?['nama'] as String? ?? '';
}
