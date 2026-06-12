class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String password;
  final String role;
  final String? cabangId;
  final Map<String, dynamic>? lokasi;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.password = '',
    required this.role,
    this.cabangId,
    this.lokasi,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['_id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String,
    password: json['password'] as String? ?? '',
    role: json['role'] as String,
    cabangId: json['cabang_id'] as String?,
    lokasi: json['lokasi'] as Map<String, dynamic>?,
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'password': password,
    'role': role,
    'cabang_id': cabangId,
    'lokasi': lokasi,
  };

  bool get isSuperAdmin => role == 'super_admin';
  bool get isAdminCabang => role == 'admin_cabang';
  bool get isDriver => role == 'driver';

  String get roleLabel {
    switch (role) {
      case 'super_admin': return 'Super Admin';
      case 'admin_cabang': return 'Admin Cabang';
      case 'driver': return 'Driver';
      default: return role;
    }
  }
}
