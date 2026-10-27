/// Validasi form. Aturan dan pesannya mengikuti skema Zod di frontend web
/// (`authSchema.ts`, `registerSchema.ts`) dan aturan backend (`auth.schema.ts`).
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email wajib diisi.';
    if (!_email.hasMatch(v)) return 'Format email tidak valid.';
    return null;
  }

  /// Login: backend hanya meminta password tidak kosong.
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi.';
    return null;
  }

  static String? name(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Nama lengkap wajib diisi.';
    if (v.length < 2) return 'Nama minimal 2 karakter.';
    if (v.length > 100) return 'Nama maksimal 100 karakter.';
    return null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi.';
    if (value.length < 8) return 'Password minimal 8 karakter.';
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return 'Konfirmasi password wajib diisi.';
      }
      if (value != original()) return 'Konfirmasi password tidak sesuai.';
      return null;
    };
  }
}
