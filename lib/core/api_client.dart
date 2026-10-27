import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'token_storage.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Klien HTTP untuk backend Express ElderCare AI.
///
/// - Menambahkan header `Authorization: Bearer <accessToken>` bila `auth: true`.
/// - Bila menerima 401, mencoba `POST /auth/refresh` satu kali lalu mengulang request
///   (sama seperti `backendFetch` di frontend web). Access token berlaku 15 menit.
/// - Respons backend berbentuk `{ success, message, data }`; yang dikembalikan
///   adalah seluruh body, pemanggil membaca `data` sendiri.
class ApiClient {
  ApiClient(this._tokens, {http.Client? client})
      : _http = client ?? http.Client();

  final TokenStorage _tokens;
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 20);

  /// Dipanggil saat sesi tidak bisa dipulihkan lagi (refresh token ditolak),
  /// supaya aplikasi kembali ke layar login.
  void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<Map<String, dynamic>> get(String path, {bool auth = true}) {
    return _send('GET', path, auth: auth);
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) {
    return _send('PATCH', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) {
    return _send('POST', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required bool auth,
    bool retry = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = await _tokens.readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    late http.Response res;
    try {
      final request = http.Request(method, _uri(path))
        ..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);

      final streamed = await _http.send(request).timeout(_timeout);
      res = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'Server tidak merespons. Periksa koneksi dan alamat API (${AppConfig.apiBaseUrl}).',
      );
    } on SocketException {
      throw _unreachable();
    } on http.ClientException {
      throw _unreachable();
    }

    if (auth && res.statusCode == 401) {
      if (retry && await _refreshOnce()) {
        return _send(method, path, body: body, auth: auth, retry: false);
      }
      // Sesi dianggap habis hanya bila refresh token sudah dihapus (ditolak server)
      // atau token baru pun tetap ditolak. Gagal jaringan saat refresh tidak logout.
      final remaining = await _tokens.readRefreshToken();
      if (!retry || remaining == null || remaining.isEmpty) {
        onSessionExpired?.call();
      }
    }

    final decoded = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;

    throw ApiException(
      _messageFrom(decoded, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  ApiException _unreachable() {
    return ApiException(
      'Tidak dapat terhubung ke server (${AppConfig.apiBaseUrl}). '
      'Pastikan backend berjalan dan HP terhubung ke laptop.',
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.bodyBytes.isEmpty) return <String, dynamic>{};
    try {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is Map<String, dynamic>) return json;
    } catch (_) {
      // Body bukan JSON (mis. halaman error dari proxy); abaikan.
    }
    return <String, dynamic>{};
  }

  String _messageFrom(Map<String, dynamic> body, int status) {
    final message = body['message'];
    if (message is String && message.trim().isNotEmpty) return message;
    final error = body['error'];
    if (error is String && error.trim().isNotEmpty) return error;
    return 'Permintaan gagal ($status).';
  }

  /// Beberapa request yang gagal 401 bersamaan hanya memicu satu refresh.
  Future<bool> _refreshOnce() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final res = await _send(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
        auth: false,
        retry: false,
      );
      final data = res['data'];
      final newToken = data is Map<String, dynamic> ? data['accessToken'] : null;
      if (newToken is String && newToken.isNotEmpty) {
        await _tokens.saveAccessToken(newToken);
        return true;
      }
    } on ApiException catch (e) {
      // Hanya hapus sesi bila server benar-benar menolak refresh token.
      // Kalau cuma gagal jaringan, token dipertahankan.
      if (e.statusCode == 401) await _tokens.clear();
    }
    return false;
  }
}
