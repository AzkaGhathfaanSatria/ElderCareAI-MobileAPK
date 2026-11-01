import 'dart:async';

import 'package:flutter/services.dart';

enum HealthConnectState { available, updateRequired, unavailable }

class WearableStatus {
  const WearableStatus({
    required this.paired,
    required this.url,
    required this.lastSync,
    required this.health,
    required this.granted,
    required this.total,
  });

  final bool paired;
  final String url;
  final DateTime? lastSync;
  final HealthConnectState health;

  /// Jumlah jenis data yang izinnya sudah diberikan, dari [total].
  final int granted;
  final int total;

  bool get hasPermissions => granted > 0;
}

class SyncResult {
  const SyncResult({
    required this.headline,
    required this.details,
    required this.ok,
  });

  final String headline;
  final String details;
  final bool ok;
}

/// Jembatan ke kode Android native (MainActivity + folder wearable/). Pembacaan Health Connect dan
/// sync berkala dikerjakan native supaya tetap jalan saat aplikasi tidak dibuka; Dart hanya mengatur
/// pairing dan menampilkan status.
class WearableBridge {
  WearableBridge._() {
    _channel.setMethodCallHandler(_onCall);
  }

  static final WearableBridge instance = WearableBridge._();

  static const MethodChannel _channel = MethodChannel('id.eldercare/wearable');

  final StreamController<String> _links = StreamController<String>.broadcast();
  String? _localPending;

  /// Tautan eldercare://pair yang masuk saat aplikasi sedang berjalan.
  Stream<String> get links => _links.stream;

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'onPairLink') {
      final link = call.arguments as String?;
      if (link == null) return null;
      if (_links.hasListener) {
        _links.add(link);
      } else {
        _localPending = link; // belum ada layar yang mendengarkan; simpan
      }
    }
    return null;
  }

  /// Tautan yang masuk sebelum Dart siap (mis. aplikasi dibuka dari "Buka di aplikasi"). Sekali ambil.
  Future<String?> takePendingLink() async {
    final fromNative = await _channel.invokeMethod<String>('takePendingLink');
    final link = fromNative ?? _localPending;
    _localPending = null;
    return link;
  }

  Future<WearableStatus> status() async {
    final m = await _channel.invokeMapMethod<String, dynamic>('status') ??
        const <String, dynamic>{};
    final millis = m['lastSyncMillis'];
    return WearableStatus(
      paired: m['paired'] == true,
      url: (m['url'] as String?) ?? '',
      lastSync: millis is int ? DateTime.fromMillisecondsSinceEpoch(millis) : null,
      health: switch (m['health']) {
        'available' => HealthConnectState.available,
        'update_required' => HealthConnectState.updateRequired,
        _ => HealthConnectState.unavailable,
      },
      granted: (m['granted'] as int?) ?? 0,
      total: (m['total'] as int?) ?? 0,
    );
  }

  Future<void> pair(String url, String key) async {
    await _channel.invokeMethod<bool>('pair', {'url': url, 'key': key});
  }

  Future<void> unpair() async {
    await _channel.invokeMethod<bool>('unpair');
  }

  /// Menampilkan dialog izin Health Connect. Mengembalikan jumlah jenis data yang diizinkan.
  Future<int> requestPermissions() async {
    return (await _channel.invokeMethod<int>('requestPermissions')) ?? 0;
  }

  Future<void> scheduleSync() async {
    await _channel.invokeMethod<bool>('scheduleSync');
  }

  Future<SyncResult> syncNow() async {
    final m = await _channel.invokeMapMethod<String, dynamic>('syncNow') ??
        const <String, dynamic>{};
    return SyncResult(
      headline: (m['headline'] as String?) ?? 'Sync selesai.',
      details: (m['details'] as String?) ?? '',
      ok: m['ok'] == true,
    );
  }

  Future<void> installHealthConnect() async {
    await _channel.invokeMethod<bool>('installHealthConnect');
  }
}
