class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? konterId;
  final String? gudangId;
  final Map<String, dynamic>? lokasi;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.konterId,
    this.gudangId,
    this.lokasi,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['_id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String,
    role: json['role'] as String,
    konterId: json['konter_id'] as String?,
    gudangId: json['gudang_id'] as String?,
    lokasi: json['lokasi'] as Map<String, dynamic>?,
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'konter_id': konterId,
    'gudang_id': gudangId,
    'lokasi': lokasi,
  };

  bool get isSuperAdmin => role == 'super_admin';
  bool get isAdminKonter => role == 'admin_konter';
  bool get isStaffGudang => role == 'staff_gudang';
  bool get isDriver => role == 'driver';

  String get roleLabel {
    switch (role) {
      case 'super_admin': return 'Super Admin';
      case 'admin_konter': return 'Admin Konter';
      case 'staff_gudang': return 'Staff Gudang';
      case 'driver': return 'Driver';
      default: return role;
    }
  }
}
