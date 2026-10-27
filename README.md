# ElderCare AI Mobile (Flutter)

Tahap 1: login dan register, tersambung ke backend Express (`ElderCareAI-Backend`).

Folder ini hanya berisi `lib/` dan `pubspec.yaml`. Folder `android/` dibuat oleh Flutter
di laptopmu (langkah 2).

## 1. Install Flutter SDK

JDK dan Android SDK sudah kamu pasang. Yang masih dibutuhkan adalah Flutter SDK
(https://docs.flutter.dev/get-started/install). Setelah itu:

```bash
flutter doctor
flutter doctor --android-licenses
```

Kalau `flutter doctor` tidak menemukan Android SDK:
`flutter config --android-sdk "<path ke Android SDK>"`.

## 2. Buat project dan masukkan kode ini

```bash
flutter create --org com.eldercare --platforms=android eldercare_mobile
cd eldercare_mobile
```

Lalu salin dari folder ini ke project yang baru dibuat:

- `pubspec.yaml` (timpa yang lama)
- folder `lib/` (timpa seluruhnya)

Hapus test bawaan yang mengacu ke aplikasi counter:

```bash
rm test/widget_test.dart      # Windows: del test\widget_test.dart
flutter pub get
```

Kalau ada konflik versi paket: `flutter pub add http flutter_secure_storage provider`.

## 3. Ubah AndroidManifest

Buka `android/app/src/main/AndroidManifest.xml`, lalu:

1. Tambahkan izin internet di dalam `<manifest>` (sebelum `<application>`):
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
2. Tambahkan `android:usesCleartextTraffic="true"` pada tag `<application>`.
   Backend lokal memakai `http://`, dan Android 9+ memblokir HTTP biasa secara default.
   Hapus atribut ini saat backend sudah memakai HTTPS (production).

Kalau build gagal karena `minSdk` (dari `flutter_secure_storage`), ubah
`minSdk` di `android/app/build.gradle(.kts)` menjadi `23`.

## 4. Jalankan backend

Backend lokal: `npm run dev` di folder backend (port 4000). Kalau lewat Docker,
pastikan port-nya dipublish (`-p 4000:4000`). Cek di browser laptop:
http://localhost:4000/health

## 5. Sambungkan HP fisik

1. HP: aktifkan Developer options, lalu USB debugging. Colok USB dan setujui prompt di HP.
2. Cek terdeteksi: `adb devices` (harus muncul status `device`).
3. Teruskan port backend ke HP:
   ```bash
   adb reverse tcp:4000 tcp:4000
   ```
   Dengan ini `http://localhost:4000` di HP menuju backend di laptop. Ulangi perintah ini
   kalau kabel dicabut atau adb di-restart.
4. Jalankan:
   ```bash
   flutter run
   ```

### Alternatif tanpa kabel (Wi-Fi)

HP dan laptop harus satu jaringan, dan firewall laptop mengizinkan port 4000:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:4000
```

Ganti `192.168.x.x` dengan IP LAN laptop (`ipconfig` / `ip a`).

## Struktur

```
lib/
  main.dart                  # entry point + AuthGate (splash / login / home)
  core/
    config.dart              # API_BASE_URL (--dart-define)
    theme.dart               # warna & tema, disalin dari web
    validators.dart          # validasi form (mengikuti Zod di web)
    token_storage.dart       # access & refresh token di secure storage
    api_client.dart          # HTTP + Bearer + auto refresh saat 401
  models/user.dart
  services/auth_service.dart # /auth/login, /register, /me, /logout
  state/auth_controller.dart # status login (Provider)
  screens/                   # login, register, home (sementara), splash
  widgets/
```

## Kontrak API yang dipakai

| Aksi     | Request                                              | Respons                                          |
|----------|------------------------------------------------------|--------------------------------------------------|
| Login    | `POST /auth/login` `{email, password}`               | `data: {accessToken, refreshToken, user}`        |
| Register | `POST /auth/register` `{nama, email, password, role}`| `201`, `data: user`                              |
| Sesi     | `GET /auth/me` (Bearer)                              | `data: {id, nama, email, noTelepon, role}`       |
| Refresh  | `POST /auth/refresh` `{refreshToken}`                | `data: {accessToken}` (berlaku 15 menit)         |
| Logout   | `POST /auth/logout` `{refreshToken}`                 | `success`                                        |

Catatan: field nama pada register adalah `nama`, bukan `name`. Role `admin` ditolak
backend (403) kecuali `ALLOW_ADMIN_REGISTER=true`.
