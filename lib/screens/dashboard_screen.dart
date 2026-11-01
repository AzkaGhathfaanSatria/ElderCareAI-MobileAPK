import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/polling.dart';
import '../core/push_service.dart';
import '../core/theme.dart';
import '../core/wearable_bridge.dart';
import '../models/elder.dart';
import '../models/user.dart';
import '../services/account_service.dart';
import '../services/elder_service.dart';
import '../state/auth_controller.dart';
import '../state/dashboard_controller.dart';
import '../widgets/common_widgets.dart';
import '../widgets/elder_widgets.dart';
import 'elder_detail_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'wearable_pairing_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, PollingMixin<DashboardScreen> {
  late final DashboardController _c;
  late final AccountService _account;
  StreamSubscription<String>? _linkSub;
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _c = DashboardController(context.read<ElderService>());
    _account = context.read<AccountService>();
    _c.load();
    _refreshUnread();
    startPolling();
    _listenPairLinks();
    _startPush();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _fgSub?.cancel();
    _openedSub?.cancel();
    stopPolling();
    _c.dispose();
    super.dispose();
  }

  /// Tautan eldercare://pair (tombol "Buka di aplikasi" di web) membuka layar Hubungkan jam.
  Future<void> _listenPairLinks() async {
    final bridge = WearableBridge.instance;
    _linkSub = bridge.links.listen(_openPairing);
    try {
      final pending = await bridge.takePendingLink();
      if (pending != null) _openPairing(pending);
    } catch (_) {
      // Bukan Android / belum ada kode native: abaikan.
    }
  }

  Future<void> _openPairing([String? link]) async {
    if (!mounted) return;
    stopPolling();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => WearablePairingScreen(initialLink: link)),
    );
    if (!mounted) return;
    startPolling();
  }

  @override
  Future<void> onPoll() => Future.wait([_c.load(silent: true), _refreshUnread()]);

  Future<void> _refreshUnread() async {
    try {
      final items = await _account.notifications();
      final n = items.where((i) => !i.read).length;
      if (mounted && n != _unread) setState(() => _unread = n);
    } catch (_) {
      // Lencana tidak kritis.
    }
  }

  Future<void> _startPush() async {
    final push = PushService.instance;
    await push.start(_account);
    if (!mounted) return;
    _fgSub = push.onForeground.listen(_onForegroundPush);
    _openedSub = push.onOpened.listen((_) => _openNotifications());
    if (push.takeInitialMessage() != null) _openNotifications();
  }

  void _onForegroundPush(RemoteMessage m) {
    if (!mounted) return;
    _refreshUnread();
    _c.load(silent: true);
    final n = m.notification;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            [n?.title, n?.body].whereType<String>().where((t) => t.isNotEmpty).join('\n'),
          ),
          action: SnackBarAction(label: 'Lihat', onPressed: _openNotifications),
        ),
      );
  }

  Future<void> _openNotifications() async {
    if (!mounted) return;
    stopPolling();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (!mounted) return;
    startPolling();
    _refreshUnread();
  }

  Future<void> _openProfile() async {
    if (!mounted) return;
    stopPolling();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    if (!mounted) return;
    startPolling();
  }

  Future<void> _logout() async {
    await PushService.instance.stop();
    if (!mounted) return;
    await context.read<AuthController>().logout();
  }

  Future<void> _open(Elder elder) async {
    // Hentikan polling dashboard selama layar detail terbuka.
    stopPolling();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ElderDetailScreen(elder: elder)),
    );
    if (!mounted) return;
    startPolling();
    _c.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthController, AppUser?>((c) => c.user);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(size: 32),
            SizedBox(width: 10),
            Text(
              'ElderCare AI',
              style: TextStyle(fontFamily: kSerif, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifikasi',
            onPressed: _openNotifications,
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text(_unread > 99 ? '99+' : '$_unread'),
              child: const Icon(Icons.notifications_none),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Akun',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'wearable') _openPairing();
              if (value == 'profile') _openProfile();
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.nama ?? '',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    Text(
                      user?.role.label ?? '',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 10),
                    Text('Profil dan pengaturan'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'wearable',
                child: Row(
                  children: [
                    Icon(Icons.watch_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Hubungkan jam'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 10),
                    Text('Keluar'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () => _c.load(silent: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: _buildChildren(user),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildren(AppUser? user) {
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Halo, ${user?.nama ?? ''}',
          style: const TextStyle(
            fontFamily: kSerif,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _c.updatedAt == null
              ? 'Memuat kondisi terbaru...'
              : 'Diperbarui ${hhmm(_c.updatedAt!)}',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
      ],
    );

    if (user?.role == UserRole.admin) {
      return [
        header,
        const StatusBanner(
          message:
              'Fitur admin hanya tersedia di versi web. Aplikasi ini untuk keluarga dan tenaga medis.',
          isError: false,
        ),
      ];
    }

    if (_c.loading && _c.items.isEmpty) {
      return [
        header,
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
      ];
    }

    if (_c.error != null && _c.items.isEmpty) {
      return [
        header,
        StatusBanner(message: _c.error!),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Coba lagi', onPressed: _c.load),
      ];
    }

    if (_c.items.isEmpty) {
      final isMedis = user?.role == UserRole.tenagaMedis;
      return [
        header,
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Text(
            isMedis
                ? 'Belum ada lansia yang dapat Anda akses. Minta keluarga lansia untuk memberi izin akses melalui versi web.'
                : 'Belum ada lansia terdaftar. Daftarkan lansia lewat versi web, lalu data akan muncul di sini.',
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
        ),
      ];
    }

    final alerts = _c.alertCount;
    return [
      header,
      if (alerts > 0) ...[
        _AttentionBanner(count: alerts),
        const SizedBox(height: 16),
      ],
      for (final item in _c.items) ...[
        _ElderCard(overview: item, onTap: () => _open(item.elder)),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return StatusBanner(
      message: count == 1
          ? '1 lansia memerlukan perhatian. Buka kartunya untuk melihat detail.'
          : '$count lansia memerlukan perhatian. Buka kartunya untuk melihat detail.',
    );
  }
}

class _ElderCard extends StatelessWidget {
  const _ElderCard({required this.overview, required this.onTap});

  final ElderOverview overview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final elder = overview.elder;
    final summary = overview.summary;
    final alert = overview.alert;

    return AppCard(
      onTap: onTap,
      borderColor: alert != null ? levelColor(alert.level) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elder.nama,
                      style: const TextStyle(
                        fontFamily: kSerif,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (elder.umur > 0)
                      Text(
                        '${elder.umur} tahun',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 12),
          if (alert != null)
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: levelColor(alert.level),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    alert.type,
                    style: TextStyle(
                      color: levelColor(alert.level),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TagChip(
                  label: alert.statusLabel,
                  color: levelColor(alert.level),
                ),
              ],
            )
          else if (summary == null)
            const Text(
              'Ringkasan tidak dapat dimuat. Tarik layar ke bawah untuk memuat ulang.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            const Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 20, color: AppColors.safe),
                SizedBox(width: 6),
                Text(
                  'Tidak ada peringatan aktif',
                  style: TextStyle(
                    color: AppColors.safe,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          if (summary != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                _Mini(
                  label: 'Detak',
                  value: summary.hasHeartRate ? '${summary.heartRate}' : '-',
                  unit: summary.hasHeartRate ? 'bpm' : null,
                ),
                _Mini(label: 'Aktivitas', value: '${summary.activity}', unit: '%'),
                _Mini(
                  label: 'Tidur',
                  value: summary.hasSleep
                      ? summary.sleepHours.toStringAsFixed(1)
                      : '-',
                  unit: summary.hasSleep ? 'jam' : null,
                ),
                _Mini(
                  label: 'Risiko',
                  value: summary.risk.label,
                  color: levelColor(summary.risk),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, this.unit, this.color});

  final String label;
  final String value;
  final String? unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            unit == null ? value : '$value $unit',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
