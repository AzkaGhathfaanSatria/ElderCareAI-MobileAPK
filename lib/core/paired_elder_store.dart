import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Mencatat lansia mana yang jamnya dipasangkan di HP ini. QR perangkat di web sudah terikat ke satu
/// lansia, tetapi aplikasi tidak tahu yang mana; catatan ini diisi saat pairing dimulai dari halaman
/// lansia, supaya kartu "Jam pintar" bisa menunjukkan status yang benar.
class PairedElder {
  const PairedElder({required this.id, required this.name});

  final String id;
  final String name;
}

class PairedElderStore {
  PairedElderStore._();

  static final PairedElderStore instance = PairedElderStore._();

  static const _idKey = 'eldercare_wearable_elder_id';
  static const _nameKey = 'eldercare_wearable_elder_name';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<PairedElder?> read() async {
    try {
      final id = await _storage.read(key: _idKey);
      if (id == null || id.isEmpty) return null;
      final name = await _storage.read(key: _nameKey) ?? '';
      return PairedElder(id: id, name: name);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String id, String name) async {
    try {
      await _storage.write(key: _idKey, value: id);
      await _storage.write(key: _nameKey, value: name);
    } catch (_) {
      // Catatan ini hanya untuk tampilan; pairing tetap berhasil.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _idKey);
      await _storage.delete(key: _nameKey);
    } catch (_) {}
  }
}
