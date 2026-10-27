import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../models/user.dart';

/// Pemanggilan endpoint `/auth/*` backend.
///
/// Kontrak backend (lihat `src/modules/auth` di repo backend):
/// - POST /auth/register  body {nama, email, password, role} -> 201 {data: user}
/// - POST /auth/login     body {email, password} -> {data: {accessToken, refreshToken, user}}
/// - GET  /auth/me        (Bearer) -> {data: {id, nama, email, noTelepon, role}}
/// - POST /auth/logout    body {refreshToken}
class AuthService {
  AuthService(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post('/auth/login', {
      'email': email,
      'password': password,
    });

    final data = res['data'];
    if (data is! Map<String, dynamic>) throw _invalidResponse();

    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];
    final userJson = data['user'];
    if (accessToken is! String ||
        refreshToken is! String ||
        userJson is! Map<String, dynamic>) {
      throw _invalidResponse();
    }

    await _tokens.saveSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    return AppUser.fromJson(userJson);
  }

  /// Registrasi tidak melakukan auto-login (sama seperti web): setelah sukses,
  /// pengguna diarahkan ke layar login.
  Future<void> register({
    required String nama,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await _api.post('/auth/register', {
      'nama': nama,
      'email': email,
      'password': password,
      'role': role.apiValue,
    });
  }

  Future<AppUser> me() async {
    final res = await _api.get('/auth/me');
    final data = res['data'];
    if (data is! Map<String, dynamic>) throw _invalidResponse();
    return AppUser.fromJson(data);
  }

  /// Memulihkan sesi dari token tersimpan. Mengembalikan null bila belum login.
  Future<AppUser?> restoreSession() async {
    final access = await _tokens.readAccessToken();
    final refresh = await _tokens.readRefreshToken();
    if ((access == null || access.isEmpty) &&
        (refresh == null || refresh.isEmpty)) {
      return null;
    }
    return me();
  }

  Future<void> logout() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _api.post('/auth/logout', {'refreshToken': refreshToken});
      } on ApiException {
        // Tetap keluar secara lokal walau server tidak terjangkau.
      }
    }
    await _tokens.clear();
  }

  ApiException _invalidResponse() {
    return ApiException('Respons dari server tidak sesuai. Coba lagi.');
  }
}
