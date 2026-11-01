import 'package:flutter/material.dart';

import '../core/paired_elder_store.dart';
import '../core/theme.dart';
import '../core/wearable_bridge.dart';
import '../models/elder.dart';
import '../screens/wearable_pairing_screen.dart';
import 'common_widgets.dart';
import 'elder_widgets.dart';

/// Kartu "Jam pintar" di halaman detail lansia: status jam dan jalan pintas ke layar Hubungkan jam.
class WearableCard extends StatefulWidget {
  const WearableCard({super.key, required this.elder, this.onOpen, this.onClosed});

  final Elder elder;

  /// Dipanggil sebelum layar pairing dibuka (mis. menghentikan polling).
  final VoidCallback? onOpen;

  /// Dipanggil setelah layar pairing ditutup (mis. memulai polling lagi dan memuat ulang data).
  final VoidCallback? onClosed;

  @override
  State<WearableCard> createState() => _WearableCardState();
}

class _WearableCardState extends State<WearableCard> {
  WearableStatus? _status;
  PairedElder? _pairedElder;
  bool _loaded = false;
  bool _unsupported = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await WearableBridge.instance.status();
      final paired = await PairedElderStore.instance.read();
      if (!mounted) return;
      setState(() {
        _status = status;
        _pairedElder = paired;
        _loaded = true;
        _unsupported = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _unsupported = true;
        });
      }
    }
  }

  Future<void> _open() async {
    widget.onOpen?.call();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WearablePairingScreen(
          elderId: widget.elder.id,
          elderName: widget.elder.nama,
        ),
      ),
    );
    if (!mounted) return;
    widget.onClosed?.call();
    _load();
  }

  String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    // Layar ini hanya ada di Android; di platform lain kartu disembunyikan.
    if (!_loaded || _unsupported) return const SizedBox.shrink();

    final status = _status;
    final paired = status?.paired == true;
    final mine = paired && _pairedElder?.id == widget.elder.id;
    final other = paired && _pairedElder != null && _pairedElder!.id != widget.elder.id;

    final IconData icon;
    final Color color;
    final String title;
    final String subtitle;
    final String action;

    if (mine) {
      final last = status?.lastSync;
      icon = Icons.watch;
      color = AppColors.safe;
      title = 'Jam terhubung';
      subtitle = last != null
          ? 'Sinkron terakhir ${_formatTime(last)}. Data dikirim otomatis.'
          : 'Belum pernah sinkron. Buka untuk sinkron sekarang.';
      action = 'Kelola';
    } else if (other) {
      icon = Icons.watch_outlined;
      color = AppColors.muted;
      title = 'Jam belum dihubungkan untuk ${widget.elder.nama}';
      subtitle = 'HP ini sedang terhubung ke jam ${_pairedElder!.name}. '
          'Putuskan dulu bila ingin memakai HP ini untuk ${widget.elder.nama}.';
      action = 'Buka';
    } else if (paired) {
      icon = Icons.watch;
      color = AppColors.safe;
      title = 'HP ini sudah terhubung ke sebuah jam';
      subtitle = 'Ketuk untuk melihat status, sinkron, atau memutuskan.';
      action = 'Kelola';
    } else {
      icon = Icons.watch_outlined;
      color = AppColors.accent;
      title = 'Hubungkan jam pintar';
      subtitle = 'Scan QR dari halaman Perangkat di website untuk mengirim data '
          'jam ${widget.elder.nama} ke dashboard.';
      action = 'Hubungkan';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        onTap: _open,
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TagChip(label: action, color: color),
          ],
        ),
      ),
    );
  }
}
