/// Isi QR pairing dari halaman Perangkat di web: `eldercare://pair?u=<alamat server>&k=<device key>`.
class PairingInfo {
  const PairingInfo({required this.url, required this.key});

  final String url;
  final String key;
}

/// Hasil membaca tautan pairing: [info] terisi bila valid, selain itu [error] berisi alasannya.
class PairingParse {
  const PairingParse.ok(PairingInfo this.info) : error = null;
  const PairingParse.error(String this.error) : info = null;

  final PairingInfo? info;
  final String? error;
}

PairingParse parsePairingLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'eldercare' || uri.host != 'pair') {
    return const PairingParse.error(
      'QR ini bukan kode pairing ElderCare. Scan kode dari halaman Perangkat di website.',
    );
  }
  return validatePairing(
    uri.queryParameters['u'] ?? '',
    uri.queryParameters['k'] ?? '',
  );
}

/// Dipakai juga oleh isian manual.
PairingParse validatePairing(String rawUrl, String rawKey) {
  var url = rawUrl.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  final key = rawKey.trim();

  final parsed = Uri.tryParse(url);
  final okUrl = parsed != null &&
      (parsed.scheme == 'http' || parsed.scheme == 'https') &&
      parsed.host.isNotEmpty;
  if (!okUrl) {
    return const PairingParse.error(
      'Alamat server tidak valid. Contoh: http://192.168.1.10:4000',
    );
  }
  if (!key.startsWith('ecw_')) {
    return const PairingParse.error(
      'Kode ini bukan untuk wearable (harus berawalan ecw_). Pastikan yang dipakai adalah QR wearable.',
    );
  }
  return PairingParse.ok(PairingInfo(url: url, key: key));
}
