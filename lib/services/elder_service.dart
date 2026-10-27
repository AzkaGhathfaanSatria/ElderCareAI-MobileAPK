import '../core/api_client.dart';
import '../models/elder.dart';

/// Endpoint monitoring lansia (lihat `monitoring.routes.ts` dan
/// `management.routes.ts` di repo backend).
///
/// - GET   /elders                    -> {data: [elder]}
/// - GET   /elders/:id/summary        -> {heartRate, activity, sleep, risk, activityHistory, hasAlert, alert}
/// - GET   /elders/:id/vitals?from&to -> {items: [{id, heartRate, sleep, timestamp}]} (maks. 1000, terlama dulu)
/// - GET   /elders/:id/history        -> {items: [...]} (90 hari terakhir)
/// - PATCH /alerts/:id                body {status: baru|ditindaklanjuti|selesai}
/// - PATCH /falls/:id/confirm         body {confirmed: bool}
class ElderService {
  ElderService(this._api);

  final ApiClient _api;

  /// Rentang data vital untuk grafik. Backend membatasi 1000 baris dan mengurutkan
  /// dari yang terlama, jadi rentang dibuat pendek agar data terbaru tidak terpotong.
  static const Duration vitalsRange = Duration(hours: 6);

  Future<List<Elder>> listElders() async {
    final res = await _api.get('/elders');
    final data = res['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(Elder.fromJson).toList();
  }

  Future<ElderSummary> summary(String elderId) async {
    final res = await _api.get('/elders/$elderId/summary');
    return ElderSummary.fromJson(res);
  }

  Future<List<VitalPoint>> vitals(String elderId) async {
    final now = DateTime.now().toUtc();
    final from = now.subtract(vitalsRange);
    final query = 'from=${Uri.encodeQueryComponent(from.toIso8601String())}'
        '&to=${Uri.encodeQueryComponent(now.toIso8601String())}';

    final res = await _api.get('/elders/$elderId/vitals?$query');
    final items = res['items'];
    if (items is! List) return const [];

    final points = <VitalPoint>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final point = VitalPoint.tryParse(item);
      if (point != null) points.add(point);
    }
    return points;
  }

  Future<List<HistoryItem>> history(String elderId) async {
    final res = await _api.get('/elders/$elderId/history');
    final items = res['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(HistoryItem.fromJson)
        .toList();
  }

  Future<void> setAlertStatus(String alertId, String status) async {
    await _api.patch('/alerts/$alertId', {'status': status});
  }

  /// `confirmed: true`  -> jatuh benar terjadi, alert menjadi "ditindaklanjuti".
  /// `confirmed: false` -> alarm palsu, alert menjadi "selesai" (hilang dari dashboard).
  Future<void> confirmFall(String fallId, {required bool confirmed}) async {
    await _api.patch('/falls/$fallId/confirm', {'confirmed': confirmed});
  }
}
