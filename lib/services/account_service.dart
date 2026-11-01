import '../core/api_client.dart';
import '../models/elder.dart';
import '../models/notification.dart';
import '../models/user.dart';

/// Endpoint akun: notifikasi, preferensi notifikasi, push token, dan profil
/// (lihat `monitoring.routes.ts` dan `management.routes.ts` di repo backend).
///
/// - GET   /notifications                 -> {data: [notifikasi]}
/// - PATCH /notifications/:id/read
/// - POST  /notifications/read-all
/// - GET   /me/notification-preferences   -> {push, dashboard, minimumLevel, ...}
/// - PUT   /me/notification-preferences   body {push, dashboard, minimumLevel}
/// - POST  /me/push-tokens                body {token, platform}
/// - DELETE /me/push-tokens               body {token}
/// - POST  /me/push-test                  -> {enabled, tokens, sent, failed, removed}
/// - PATCH /me                            body {nama} -> {user}
class AccountService {
  AccountService(this._api);

  final ApiClient _api;

  Future<List<AppNotification>> notifications() async {
    final res = await _api.get('/notifications');
    final data = res['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<void> markRead(String id) async {
    await _api.patch('/notifications/$id/read', <String, dynamic>{});
  }

  Future<void> markAllRead() async {
    await _api.post('/notifications/read-all', <String, dynamic>{}, auth: true);
  }

  Future<NotificationPrefs> preferences() async {
    final res = await _api.get('/me/notification-preferences');
    return NotificationPrefs.fromJson(res);
  }

  Future<NotificationPrefs> savePreferences(NotificationPrefs prefs) async {
    final res = await _api.put('/me/notification-preferences', {
      'push': prefs.push,
      'dashboard': prefs.dashboard,
      'minimumLevel': prefs.minimumLevel.label,
    });
    return NotificationPrefs.fromJson(res);
  }

  Future<void> registerPushToken(String token) async {
    await _api.post(
      '/me/push-tokens',
      {'token': token, 'platform': 'android'},
      auth: true,
    );
  }

  Future<void> unregisterPushToken(String token) async {
    await _api.delete('/me/push-tokens', body: {'token': token});
  }

  Future<PushTestResult> sendTestPush() async {
    final res = await _api.post('/me/push-test', <String, dynamic>{}, auth: true);
    return PushTestResult.fromJson(res);
  }

  /// Mengembalikan pengguna terbaru dari server.
  Future<AppUser> updateName(String nama) async {
    final res = await _api.patch('/me', {'nama': nama});
    final user = res['user'];
    if (user is! Map<String, dynamic>) {
      throw ApiException('Respons dari server tidak sesuai. Coba lagi.');
    }
    return AppUser.fromJson(user);
  }
}
