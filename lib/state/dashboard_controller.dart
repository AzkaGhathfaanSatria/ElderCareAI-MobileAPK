import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/elder.dart';
import '../services/elder_service.dart';

class ElderOverview {
  const ElderOverview(this.elder, this.summary);

  final Elder elder;

  /// Null bila ringkasan lansia ini gagal dimuat (lansia tetap ditampilkan).
  final ElderSummary? summary;

  ActiveAlert? get alert => summary?.alert;
}

class DashboardController extends ChangeNotifier {
  DashboardController(this._service);

  final ElderService _service;

  List<ElderOverview> items = const [];
  bool loading = true;
  String? error;
  DateTime? updatedAt;

  bool _disposed = false;
  bool _fetching = false;

  /// [silent] true untuk refresh berkala: tidak menampilkan spinner dan tidak
  /// menimpa data lama dengan pesan error bila sudah ada data.
  Future<void> load({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;

    if (!silent) {
      loading = true;
      error = null;
      _notify();
    }

    try {
      final elders = await _service.listElders();
      final overviews = await Future.wait(elders.map(_overviewFor));
      overviews.sort(_byUrgency);
      items = overviews;
      error = null;
      updatedAt = DateTime.now();
    } on ApiException catch (e) {
      if (!silent || items.isEmpty) error = e.message;
    } catch (_) {
      if (!silent || items.isEmpty) {
        error = 'Data dari server tidak sesuai. Coba lagi.';
      }
    } finally {
      loading = false;
      _fetching = false;
      _notify();
    }
  }

  Future<ElderOverview> _overviewFor(Elder elder) async {
    try {
      return ElderOverview(elder, await _service.summary(elder.id));
    } catch (_) {
      return ElderOverview(elder, null);
    }
  }

  /// Lansia dengan alert tertinggi di atas; sisanya urut nama.
  static int _byUrgency(ElderOverview a, ElderOverview b) {
    final la = a.alert?.level.index ?? -1;
    final lb = b.alert?.level.index ?? -1;
    if (la != lb) return lb.compareTo(la);
    return a.elder.nama.toLowerCase().compareTo(b.elder.nama.toLowerCase());
  }

  int get alertCount => items.where((o) => o.alert != null).length;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
