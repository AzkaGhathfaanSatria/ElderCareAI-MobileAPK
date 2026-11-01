import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../services/account_service.dart';

enum PushState {
  /// Belum dijalankan (belum login).
  idle,

  /// Firebase belum dikonfigurasi di aplikasi (google-services.json tidak ada) atau gagal diinisialisasi.
  unavailable,

  /// Pengguna menolak izin notifikasi.
  denied,

  /// Token terdaftar di backend; push akan diterima.
  active,
}

/// Push notification (FCM). Aman dipakai walau Firebase belum disiapkan: bila inisialisasi gagal,
/// state menjadi [PushState.unavailable] dan aplikasi tetap jalan (alert tetap terlihat lewat polling).
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final StreamController<RemoteMessage> _foreground =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _opened =
      StreamController<RemoteMessage>.broadcast();

  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  AccountService? _account;
  String? _token;
  RemoteMessage? _initialMessage;

  PushState state = PushState.idle;

  /// Pesan yang tiba saat aplikasi sedang dibuka.
  Stream<RemoteMessage> get onForeground => _foreground.stream;

  /// Pengguna mengetuk notifikasi saat aplikasi di background.
  Stream<RemoteMessage> get onOpened => _opened.stream;

  /// Pesan yang membuka aplikasi dari keadaan tertutup. Sekali ambil.
  RemoteMessage? takeInitialMessage() {
    final m = _initialMessage;
    _initialMessage = null;
    return m;
  }

  String get description {
    switch (state) {
      case PushState.active:
        return 'Aktif di HP ini.';
      case PushState.denied:
        return 'Izin notifikasi ditolak. Aktifkan lewat pengaturan Android (Aplikasi > ElderCare AI > Notifikasi).';
      case PushState.unavailable:
        return 'Belum dikonfigurasi di aplikasi (file google-services.json belum dipasang).';
      case PushState.idle:
        return 'Belum dijalankan.';
    }
  }

  /// Minta izin, ambil token FCM, daftarkan ke backend. Aman dipanggil berulang.
  Future<void> start(AccountService account) async {
    if (state == PushState.active) return;
    _account = account;

    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (_) {
      state = PushState.unavailable;
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        state = PushState.denied;
        return;
      }

      _token = await messaging.getToken();
      final token = _token;
      if (token != null) await account.registerPushToken(token);

      _refreshSub ??= messaging.onTokenRefresh.listen((t) {
        _token = t;
        _account?.registerPushToken(t).catchError((Object _) {});
      });
      _messageSub ??= FirebaseMessaging.onMessage.listen(_foreground.add);
      _openedSub ??= FirebaseMessaging.onMessageOpenedApp.listen(_opened.add);
      _initialMessage ??= await messaging.getInitialMessage();

      state = PushState.active;
    } catch (_) {
      state = PushState.unavailable;
    }
  }

  /// Dipanggil saat logout: perangkat ini berhenti menerima notifikasi akun tersebut.
  Future<void> stop() async {
    final token = _token;
    _token = null;
    if (token != null) {
      try {
        await _account?.unregisterPushToken(token);
      } catch (_) {
        // Tetap lanjut keluar walau server tidak terjangkau.
      }
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
    state = PushState.idle;
  }
}
