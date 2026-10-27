import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/elder.dart';
import '../services/elder_service.dart';

class ElderDetailController extends ChangeNotifier {
  ElderDetailController(this._service, this.elderId);

  final ElderService _service;
  final String elderId;

  ElderSummary? summary;
  List<VitalPoint> vitals = const [];
  List<HistoryItem> history = const [];

  bool loading = true;

  /// True saat aksi alert (konfirmasi/ubah status) sedang dikirim.
  bool busy = false;
  String? error;
  DateTime? updatedAt;

  bool _disposed = false;
  bool _fetching = false;
  bool _fetchAgain = false;

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    await _fetch(silent: false);
  }

  /// Refresh berkala tanpa spinner.
  Future<void> refresh() async {
    if (busy) return;
    await _fetch(silent: true);
  }

  Future<void> _fetch({required bool silent}) async {
    if (_fetching) {
      _fetchAgain = true;
      return;
    }
    _fetching = true;

    try {
      // Vital dan riwayat tidak kritis: bila gagal, bagian itu kosong saja.
      final summaryF = _service.summary(elderId);
      final vitalsF =
          _service.vitals(elderId).catchError((_) => <VitalPoint>[]);
      final historyF =
          _service.history(elderId).catchError((_) => <HistoryItem>[]);

      summary = await summaryF;
      vitals = await vitalsF;
      history = await historyF;
      error = null;
      updatedAt = DateTime.now();
    } on ApiException catch (e) {
      if (!silent || summary == null) error = e.message;
    } catch (_) {
      if (!silent || summary == null) {
        error = 'Data dari server tidak sesuai. Coba lagi.';
      }
    } finally {
      loading = false;
      _fetching = false;
      _notify();
    }

    if (_fetchAgain) {
      _fetchAgain = false;
      await _fetch(silent: true);
    }
  }

  /// Mengembalikan pesan error, atau null bila berhasil.
  Future<String?> confirmFall({required bool confirmed}) {
    final fallId = summary?.alert?.fallId;
    if (fallId == null) {
      return Future.value('Data kejadian jatuh tidak ditemukan.');
    }
    return _act(() => _service.confirmFall(fallId, confirmed: confirmed));
  }

  Future<String?> setAlertStatus(String status) {
    final alertId = summary?.alert?.id;
    if (alertId == null) return Future.value('Alert tidak ditemukan.');
    return _act(() => _service.setAlertStatus(alertId, status));
  }

  Future<String?> _act(Future<void> Function() action) async {
    busy = true;
    _notify();

    String? failure;
    try {
      await action();
    } on ApiException catch (e) {
      failure = e.message;
    } catch (_) {
      failure = 'Terjadi kesalahan. Coba lagi.';
    }

    busy = false;
    _notify();

    if (failure == null) await _fetch(silent: true);
    return failure;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
