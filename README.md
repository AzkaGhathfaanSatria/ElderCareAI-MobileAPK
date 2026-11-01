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

## Hubungkan jam (wearable)

Data jam (mis. Aolon Mars R4) dibaca dari Health Connect lalu dikirim ke `POST /ingest/wearable`.

Alur pengguna:
1. Di website: halaman Perangkat, daftarkan wearable, muncul QR. Isi kolom "Alamat server" di bawah QR dengan
   IP laptop (mis. `http://192.168.1.10:4000`).
2. Di aplikasi: ikon akun (kanan atas) lalu **Hubungkan jam**, ketuk **Scan QR**.
3. Beri izin Health Connect. Data pertama langsung terkirim, lalu sync otomatis tiap 15 menit.

Alternatif: bila website dibuka di HP yang sama, ketuk "Buka di aplikasi" di bawah QR. Bila scan bermasalah, ada
"Isi manual" (alamat server + device key `ecw_...`).

Catatan teknis:
- Pembacaan Health Connect dan sync berkala ditulis native (Kotlin, folder
  `android/app/src/main/kotlin/com/eldercare/eldercare_mobile/wearable/`) dan berbicara ke Dart lewat
  `MethodChannel('id.eldercare/wearable')` (`lib/core/wearable_bridge.dart`). Sengaja tidak memakai plugin Flutter
  `health` + `workmanager`: tugas latar belakang Flutter berjalan di isolate terpisah dan plugin kesehatan di sana
  rawan gagal, sedangkan WorkManager native tidak butuh mesin Flutter.
- `MainActivity` sekarang `FlutterFragmentActivity` (dibutuhkan untuk dialog izin Health Connect).
- `minSdk` dinaikkan ke 28 (Health Connect butuh Android 9+).
- Alamat server pairing berasal dari QR, terpisah dari `API_BASE_URL` (yang dipakai login dan dashboard).
- Metrik yang dikirim: detak jantung, SpO2, HRV (RMSSD), suhu, tidur. Akselerometer dan giroskop tidak ada di
  Health Connect, jadi analisis AI sensor (jatuh) belum jalan dari data jam ini.
- Setelah menimpa file ini ke repo, jalankan `flutter pub get` (menambah `mobile_scanner`).
- Kode native belum pernah dikompilasi/diuji di lingkungan penulisan; kemungkinan perlu penyesuaian kecil.

## Notifikasi push (Firebase)

Peringatan dari backend (jatuh, detak abnormal, dll.) dikirim ke HP lewat Firebase Cloud Messaging, termasuk saat
aplikasi ditutup. Tanpa Firebase aplikasi tetap jalan; peringatan tetap muncul lewat polling 15 detik dan layar Notifikasi.

1. Buat project di https://console.firebase.google.com (gratis, tanpa kartu kredit).
2. Tambah aplikasi Android dengan package `com.eldercare.eldercare_mobile`. Unduh `google-services.json` dan
   taruh di `android/app/` (jangan di-commit).
3. Project settings > Service accounts > Generate new private key. Simpan JSON-nya di laptop (di luar repo), lalu isi
   backend `.env`: `FCM_SERVICE_ACCOUNT_FILE=C:/path/ke/kunci.json` dan restart backend.
4. Di folder aplikasi: `flutter pub get`, lalu jalankan ulang aplikasi (bukan hot reload).
5. Di aplikasi: menu akun > Profil dan pengaturan > Kirim notifikasi uji. Status "Push di HP ini" harus "Aktif".

Layar tambahan: Notifikasi (ikon lonceng), Profil dan pengaturan, Lupa password. Di Lupa password, tempel token
(atau seluruh tautan) dari email karena tautan emailnya mengarah ke website.

Catatan: jangan menimpa `pubspec.lock` milik Anda; jalankan `flutter pub get` setelah menimpa file.

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
