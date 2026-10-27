enum UserRole {
  admin('admin', 'Admin'),
  keluarga('keluarga', 'Keluarga'),
  tenagaMedis('tenaga_medis', 'Tenaga Medis');

  const UserRole(this.apiValue, this.label);

  /// Nilai yang dikirim/diterima dari backend.
  final String apiValue;

  /// Teks untuk ditampilkan di UI.
  final String label;

  static UserRole fromApi(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.apiValue == value,
      orElse: () => UserRole.keluarga,
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.nama,
    required this.email,
    required this.role,
    this.noTelepon,
  });

  final int id;
  final String nama;
  final String email;
  final UserRole role;
  final String? noTelepon;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num).toInt(),
      nama: (json['nama'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: UserRole.fromApi(json['role'] as String?),
      noTelepon: json['noTelepon'] as String?,
    );
  }
}
