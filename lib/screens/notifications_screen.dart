import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/elder.dart';
import '../models/notification.dart';
import '../services/account_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/elder_widgets.dart';
import 'elder_detail_screen.dart';

/// Daftar notifikasi (sama dengan halaman Notifikasi di web). Ketuk item untuk membuka detail lansia.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final AccountService _service;
  List<AppNotification> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = context.read<AccountService>();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final items = await _service.notifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Notifikasi tidak dapat dimuat.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _unread => _items.where((n) => !n.read).length;

  Future<void> _markAll() async {
    try {
      await _service.markAllRead();
      if (!mounted) return;
      setState(() => _items = _items.map((n) => n.markedRead()).toList());
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gagal menandai notifikasi.');
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      setState(() {
        _items = [for (final i in _items) i.id == n.id ? i.markedRead() : i];
      });
      try {
        await _service.markRead(n.id);
      } catch (_) {
        // Tidak kritis; status baca akan sinkron saat dimuat ulang.
      }
    }
    if (!mounted || n.elderId.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ElderDetailScreen(
          elder: Elder(
            id: n.elderId,
            nama: n.elderName,
            umur: 0,
            alamat: '',
            catatanKesehatan: '',
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(DateTime? t) {
    if (t == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAll,
              child: const Text('Tandai semua dibaca'),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () => _load(silent: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: _buildChildren(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildren() {
    if (_loading && _items.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 64),
          child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
        ),
      ];
    }
    if (_error != null && _items.isEmpty) {
      return [
        StatusBanner(message: _error!),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Coba lagi', onPressed: _load),
      ];
    }
    if (_items.isEmpty) {
      return const [
        AppCard(
          padding: EdgeInsets.all(20),
          child: Text(
            'Belum ada notifikasi.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      ];
    }
    return [
      for (final n in _items) ...[
        _NotificationTile(
          item: n,
          timeLabel: _formatTime(n.createdAt),
          onTap: () => _open(n),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.timeLabel,
    required this.onTap,
  });

  final AppNotification item;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(item.level);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: item.read ? null : color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5, right: 12),
            decoration: BoxDecoration(
              color: item.read ? AppColors.border : color,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(color: AppColors.inkSoft, height: 1.35),
                  ),
                ],
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    timeLabel,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          TagChip(label: item.level.label, color: color),
        ],
      ),
    );
  }
}
