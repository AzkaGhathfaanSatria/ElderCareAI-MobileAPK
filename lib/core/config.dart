/// Konfigurasi aplikasi.
///
/// Base URL API bisa diganti saat run/build tanpa mengubah kode:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000
///
/// Default `http://localhost:4000` dipakai bersama `adb reverse tcp:4000 tcp:4000`
/// (HP fisik lewat kabel USB), jadi HP mengakses backend di laptop tanpa perlu IP LAN.
class AppConfig {
  AppConfig._();

  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  static String get apiBaseUrl => _rawBaseUrl.endsWith('/')
      ? _rawBaseUrl.substring(0, _rawBaseUrl.length - 1)
      : _rawBaseUrl;
}
