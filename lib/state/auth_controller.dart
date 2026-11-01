import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  AuthController(this._service);

  final AuthService _service;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;

  AuthStatus get status => _status;
  AppUser? get user => _user;

  /// Dipanggil sekali saat aplikasi dibuka: pulihkan sesi bila token masih valid.
  Future<void> bootstrap() async {
    try {
      final restored = await _service.restoreSession();
      _user = restored;
      _status = restored == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    } on ApiException {
      // Token ditolak atau server tidak terjangkau: tampilkan layar login.
      _user = null;
      _status = AuthStatus.unauthenticated;
    } catch (_) {
      _user = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Melempar [ApiException] bila gagal; layar login menampilkan pesannya.
  Future<void> login({required String email, required String password}) async {
    final user = await _service.login(email: email, password: password);
    _user = user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> register({
    required String nama,
    required String email,
    required String password,
    required UserRole role,
  }) {
    return _service.register(
      nama: nama,
      email: email,
      password: password,
      role: role,
    );
  }

  Future<void> forgotPassword(String email) => _service.forgotPassword(email);

  Future<void> resetPassword({required String token, required String password}) {
    return _service.resetPassword(token: token, password: password);
  }

  /// Dipakai layar profil setelah nama diubah.
  void updateUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  /// Dipanggil ApiClient saat refresh token ditolak: kembali ke layar login.
  void handleSessionExpired() {
    if (_status == AuthStatus.unauthenticated) return;
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
