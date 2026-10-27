import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/polling.dart';
import '../core/theme.dart';
import '../models/elder.dart';
import '../services/elder_service.dart';
import '../state/elder_detail_controller.dart';
import '../widgets/common_widgets.dart';
import '../widgets/elder_widgets.dart';

class ElderDetailScreen extends StatefulWidget {
  const ElderDetailScreen({super.key, required this.elder});

  final Elder elder;

  @override
  State<ElderDetailScreen> createState() => _ElderDetailScreenState();
}

class _ElderDetailScreenState extends State<ElderDetailScreen>
    with WidgetsBindingObserver, PollingMixin<ElderDetailScreen> {
  late final ElderDetailController _c;
  bool _showAllHistory = false;

  static const int _historyPreview = 5;

  @override
  void initState() {
    super.initState();
    _c = ElderDetailController(context.read<ElderService>(), widget.elder.id);
    _c.load();
    startPolling();
  }

  @override
  void dispose() {
    stopPolling();
    _c.dispose();
    super.dispose();
  }

  @override
  Future<void> onPoll() => _c.refresh();

  /// Dialog konfirmasi, lalu jalankan aksi dan tampilkan hasilnya di SnackBar.
  Future<void> _confirmAndRun({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<String?> Function() action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final error = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error ?? 'Berhasil diperbarui.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.elder.nama)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _c.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: _buildChildren(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildren() {
    final summary = _c.summary;

    if (_c.loading && summary == null) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 64),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
      ];
    }

    if (summary == null) {
      return [
        StatusBanner(message: _c.error ?? 'Data tidak dapat dimuat.'),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Coba lagi', onPressed: _c.load),
      ];
    }

    final alert = summary.alert;
    final history = _showAllHistory
        ? _c.history
        : _c.history.take(_historyPreview).toList();

    return [
      _ProfileCard(elder: widget.elder, updatedAt: _c.updatedAt),
      const SizedBox(height: 16),
      if (_c.error != null) ...[
        StatusBanner(message: _c.error!),
        const SizedBox(height: 16),
      ],
      if (alert != null) ...[
        _AlertCard(
          alert: alert,
          busy: _c.busy,
          onConfirmFall: () => _confirmAndRun(
            title: 'Konfirmasi jatuh',
            message:
                'Jatuh benar terjadi pada ${widget.elder.nama}? Alert akan ditandai sebagai ditindaklanjuti.',
            confirmLabel: 'Ya, jatuh',
            action: () => _c.confirmFall(confirmed: true),
          ),
          onFalseAlarm: () => _confirmAndRun(
            title: 'Tandai alarm palsu',
            message:
                'Tidak ada kejadian jatuh? Alert akan ditutup dan hilang dari dashboard.',
            confirmLabel: 'Alarm palsu',
            action: () => _c.confirmFall(confirmed: false),
          ),
          onFollowUp: () => _confirmAndRun(
            title: 'Tindak lanjuti alert',
            message: 'Tandai alert ini sedang ditindaklanjuti?',
            confirmLabel: 'Tandai',
            action: () =>
                _c.setAlertStatus(ActiveAlert.statusDitindaklanjuti),
          ),
          onResolve: () => _confirmAndRun(
            title: 'Selesaikan alert',
            message:
                'Tandai alert ini selesai? Alert akan hilang dari dashboard.',
            confirmLabel: 'Selesai',
            action: () => _c.setAlertStatus(ActiveAlert.statusSelesai),
          ),
        ),
        const SizedBox(height: 16),
      ] else ...[
        const AppCard(
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.safe),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tidak ada peringatan aktif.',
                  style: TextStyle(
                    color: AppColors.safe,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
        children: [
          StatTile(
            icon: Icons.favorite_outline,
            label: 'Detak jantung',
            value: summary.hasHeartRate ? '${summary.heartRate}' : '-',
            unit: summary.hasHeartRate ? 'bpm' : null,
          ),
          StatTile(
            icon: Icons.directions_walk,
            label: 'Aktivitas hari ini',
            value: '${summary.activity}',
            unit: '%',
          ),
          StatTile(
            icon: Icons.bedtime_outlined,
            label: 'Tidur',
            value: summary.hasSleep
                ? summary.sleepHours.toStringAsFixed(1)
                : '-',
            unit: summary.hasSleep ? 'jam' : null,
          ),
          StatTile(
            icon: Icons.shield_outlined,
            label: 'Tingkat risiko',
            value: summary.risk.label,
            color: levelColor(summary.risk),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const SectionTitle('Detak jantung'),
      const SizedBox(height: 4),
      const Text(
        '6 jam terakhir',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 12),
      AppCard(child: HeartRateChart(points: _c.vitals)),
      const SizedBox(height: 24),
      const SectionTitle('Aktivitas 7 hari'),
      const SizedBox(height: 12),
      AppCard(child: ActivityBars(days: summary.activityHistory)),
      const SizedBox(height: 24),
      SectionTitle(
        'Riwayat anomali',
        trailing: _c.history.length > _historyPreview
            ? TextButton(
                onPressed: () =>
                    setState(() => _showAllHistory = !_showAllHistory),
                child: Text(
                  _showAllHistory ? 'Ringkas' : 'Lihat semua (${_c.history.length})',
                ),
              )
            : null,
      ),
      const SizedBox(height: 12),
      if (_c.history.isEmpty)
        const AppCard(
          child: Text(
            'Belum ada anomali dalam 90 hari terakhir.',
            style: TextStyle(color: AppColors.muted),
          ),
        )
      else
        for (final item in history) ...[
          _HistoryTile(item: item),
          const SizedBox(height: 10),
        ],
    ];
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.elder, required this.updatedAt});

  final Elder elder;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (elder.umur > 0)
            Text(
              '${elder.umur} tahun',
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (elder.alamat.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined,
                    size: 18, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    elder.alamat,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ],
          if (elder.catatanKesehatan.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.medical_information_outlined,
                    size: 18, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    elder.catatanKesehatan,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ],
          if (updatedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Diperbarui ${hhmm(updatedAt!)}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.busy,
    required this.onConfirmFall,
    required this.onFalseAlarm,
    required this.onFollowUp,
    required this.onResolve,
  });

  final ActiveAlert alert;
  final bool busy;
  final VoidCallback onConfirmFall;
  final VoidCallback onFalseAlarm;
  final VoidCallback onFollowUp;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(alert.level);
    final isNew = alert.status == ActiveAlert.statusBaru;
    // Alert jatuh yang belum dikonfirmasi: tanyakan dulu jatuh benar atau tidak.
    final needsFallConfirmation = alert.fallId != null && isNew;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.type,
                  style: TextStyle(
                    fontFamily: kSerif,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              TagChip(label: 'Risiko ${alert.level.label}', color: color),
              TagChip(label: alert.statusLabel, color: AppColors.inkSoft),
            ],
          ),
          if (alert.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              alert.description,
              style: const TextStyle(color: AppColors.ink, height: 1.4),
            ),
          ],
          if (alert.detected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Terdeteksi ${alert.detected}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 16),
          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (needsFallConfirmation) ...[
            ElevatedButton(
              onPressed: onConfirmFall,
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text('Ya, lansia terjatuh'),
            ),
            const SizedBox(height: 10),
            _SecondaryButton(label: 'Alarm palsu', onPressed: onFalseAlarm),
          ] else if (isNew) ...[
            ElevatedButton(
              onPressed: onFollowUp,
              child: const Text('Tandai ditindaklanjuti'),
            ),
            const SizedBox(height: 10),
            _SecondaryButton(label: 'Tandai selesai', onPressed: onResolve),
          ] else
            ElevatedButton(
              onPressed: onResolve,
              child: const Text('Tandai selesai'),
            ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(item.level);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5, right: 12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.type,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.date} • ${item.time}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: const TextStyle(color: AppColors.inkSoft, height: 1.35),
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
