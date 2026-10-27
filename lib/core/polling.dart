import 'dart:async';

import 'package:flutter/widgets.dart';

/// Memanggil [onPoll] secara berkala selama layar terlihat dan aplikasi di
/// foreground. Saat aplikasi masuk background timer dihentikan, dan saat kembali
/// langsung refresh sekali.
///
/// Dipakai sebagai pengganti SSE di web: koneksi SSE tidak andal di app mobile
/// yang sering berpindah ke background.
///
/// Pemakaian:
/// ```dart
/// class _S extends State<W> with WidgetsBindingObserver, PollingMixin<W> {
///   initState: startPolling();
///   dispose:   stopPolling();
///   Future<void> onPoll() => controller.refresh();
/// }
/// ```
mixin PollingMixin<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  Timer? _timer;

  Duration get pollInterval => const Duration(seconds: 15);

  Future<void> onPoll();

  void startPolling() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void stopPolling() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) {
      onPoll();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      onPoll();
      _schedule();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }
}
