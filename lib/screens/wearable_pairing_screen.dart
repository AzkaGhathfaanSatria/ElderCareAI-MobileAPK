import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/paired_elder_store.dart';
import '../core/pairing_link.dart';
import '../core/theme.dart';
import '../core/wearable_bridge.dart';
import '../widgets/app_text_field.dart';
import '../widgets/common_widgets.dart';
import '../widgets/elder_widgets.dart';
import 'qr_scan_screen.dart';

/// Hubungkan jam ke dashboard: scan QR dari halaman Perangkat di website -> izin Health Connect -> selesai.
/// Setelah itu sync berjalan otomatis tiap 15 menit (dikerjakan kode native, tidak perlu aplikasi dibuka).
class WearablePairingScreen extends StatefulWidget {
  const WearablePairingScreen({
    super.key,
    this.initialLink,
    this.elderId,
    this.elderName,
  });

  /// Lansia yang halamannya membuka layar ini (null bila dibuka dari menu akun).
  final String? elderId;
  final String? elderName;

  /// Tautan eldercare://pair yang membuka aplikasi (dari tombol "Buka di aplikasi" di web).
  final String? initialLink;

  @override
  State<WearablePairingScreen> createState() => _WearablePairingScreenState();
}

class _WearablePairingScreenState extends State<WearablePairingScreen> {
  final WearableBridge _bridge = WearableBridge.instance;
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _keyCtrl = TextEditingController();
  StreamSubscription<String>? _linkSub;

  WearableStatus? _status;
  String _message = '';
  String _details = '';
  bool _isError = false;
  bool _busy = false;
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    _linkSub = _bridge.links.listen(_handleScanned);
    _refresh().then((_) {
      final link = widget.initialLink;
      if (link != null && mounted) _handleScanned(link);
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final s = await _bridge.status();
      if (mounted) setState(() => _status = s);
    } catch (e) {
      if (mounted) {
        _show(
          'Fitur ini hanya tersedia di aplikasi Android.',
          error: true,
          details: _errorText(e),
        );
      }
    }
  }

  String _errorText(Object e) => e is PlatformException ? (e.message ?? e.code) : '$e';

  void _show(String message, {bool error = false, String details = ''}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _details = details;
      _isError = error;
    });
  }

  // ------------------------------------------------------------------ pairing

  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (raw != null && mounted) _handleScanned(raw);
  }

  void _handleScanned(String raw) {
    if (_busy) return;
    final parsed = parsePairingLink(raw);
    final info = parsed.info;
    if (info == null) {
      _show(parsed.error ?? 'QR tidak valid.', error: true);
      return;
    }
    _pairAndSetup(info);
  }

  void _submitManual() {
    if (_busy) return;
    final parsed = validatePairing(_urlCtrl.text, _keyCtrl.text);
    final info = parsed.info;
    if (info == null) {
      _show(parsed.error ?? 'Isian tidak valid.', error: true);
      return;
    }
    _pairAndSetup(info);
  }

  Future<void> _pairAndSetup(PairingInfo info) async {
    setState(() {
      _busy = true;
      _message = '';
      _details = '';
    });
    try {
      await _bridge.pair(info.url, info.key);
      final elderId = widget.elderId;
      if (elderId != null) {
        await PairedElderStore.instance.save(elderId, widget.elderName ?? '');
      } else {
        await PairedElderStore.instance.clear();
      }
      await _refresh();

      final status = _status;
      if (status != null && status.health != HealthConnectState.available) {
        _show(
          'Perangkat tersimpan, tetapi Health Connect belum siap di HP ini. '
          'Pasang atau perbarui Health Connect, lalu buka layar ini lagi.',
          error: true,
        );
        await _bridge.installHealthConnect();
        return;
      }

      _show('Perangkat terhubung. Meminta izin membaca data kesehatan...');
      final granted = await _bridge.requestPermissions();
      await _refresh();
      if (granted == 0) {
        _show(
          'Izin Health Connect belum diberikan, jadi data belum bisa dibaca. '
          'Ketuk "Beri izin" untuk mencoba lagi.',
          error: true,
        );
        return;
      }

      await _bridge.scheduleSync();
      await _runSync();
    } catch (e) {
      _show('Gagal menghubungkan perangkat.', error: true, details: _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPermissionsAgain() async {
    setState(() => _busy = true);
    try {
      final granted = await _bridge.requestPermissions();
      await _refresh();
      if (granted == 0) {
        _show('Izin belum diberikan.', error: true);
      } else {
        await _bridge.scheduleSync();
        await _runSync();
      }
    } catch (e) {
      _show('Tidak bisa meminta izin.', error: true, details: _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    try {
      await _runSync();
    } catch (e) {
      _show('Terjadi kesalahan saat sync.', error: true, details: _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runSync() async {
    _show('Menyinkronkan data...');
    final r = await _bridge.syncNow();
    _show(r.headline, error: !r.ok, details: r.details);
    await _refresh();
  }

  Future<void> _confirmUnpair() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Putuskan perangkat'),
        content: const Text(
          'Data jam tidak akan dikirim lagi sampai dipasangkan ulang. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Putuskan'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _bridge.unpair();
      await PairedElderStore.instance.clear();
      _show('Perangkat diputuskan.');
      await _refresh();
    } catch (e) {
      _show('Gagal memutuskan perangkat.', error: true, details: _errorText(e));
    }
  }

  // ------------------------------------------------------------------ UI

  String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hubungkan jam')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (_status == null && _message.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              )
            else if (_status?.paired == true)
              ..._pairedChildren(_status!)
            else
              ..._unpairedChildren(),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 16),
              StatusBanner(message: _message, isError: _isError),
            ],
            if (_details.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                _details,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _unpairedChildren() {
    return [
      AppCard(
        child: Text(
          widget.elderName != null
              ? 'Hubungkan jam ${widget.elderName} ke dashboard dalam satu langkah: buka halaman '
                  'Perangkat di website, pilih atau daftarkan jam untuk ${widget.elderName}, '
                  'lalu scan kode QR yang muncul.'
              : 'Hubungkan jam Anda ke dashboard dalam satu langkah: buka halaman '
                  'Perangkat di website, daftarkan jam, lalu scan kode QR yang muncul.',
          style: const TextStyle(color: AppColors.inkSoft, height: 1.45),
        ),
      ),
      const SizedBox(height: 16),
      PrimaryButton(label: 'Scan QR', loading: _busy, onPressed: _scan),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _busy ? null : () => setState(() => _manual = !_manual),
          child: Text(_manual ? 'Sembunyikan isian manual' : 'Tidak bisa scan? Isi manual'),
        ),
      ),
      if (_manual) ...[
        AppTextField(
          label: 'Alamat server',
          controller: _urlCtrl,
          hint: 'http://192.168.1.10:4000',
          keyboardType: TextInputType.url,
          enabled: !_busy,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Device key',
          controller: _keyCtrl,
          hint: 'ecw_...',
          enabled: !_busy,
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Hubungkan', loading: _busy, onPressed: _submitManual),
      ],
    ];
  }

  List<Widget> _pairedChildren(WearableStatus s) {
    final last = s.lastSync;
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.safe),
                SizedBox(width: 8),
                Text(
                  'Terhubung',
                  style: TextStyle(
                    fontFamily: kSerif,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.safe,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              last != null ? 'Terakhir sync: ${_formatTime(last)}' : 'Belum pernah sync',
              style: const TextStyle(color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Izin data: ${s.granted} dari ${s.total} jenis',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              'Server: ${s.url}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            const Text(
              'Data dikirim otomatis tiap 15 menit. Tidak ada yang perlu dilakukan lagi.',
              style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (s.health != HealthConnectState.available) ...[
        const StatusBanner(
          message: 'Health Connect belum siap di HP ini. Pasang atau perbarui dulu.',
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Buka Play Store',
          onPressed: _busy ? null : _bridge.installHealthConnect,
        ),
      ] else if (!s.hasPermissions) ...[
        PrimaryButton(
          label: 'Beri izin Health Connect',
          loading: _busy,
          onPressed: _requestPermissionsAgain,
        ),
      ] else
        PrimaryButton(label: 'Sync sekarang', loading: _busy, onPressed: _syncNow),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _busy ? null : _confirmUnpair,
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Putuskan perangkat'),
        ),
      ),
    ];
  }
}
