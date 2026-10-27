import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/elder.dart';

Color levelColor(RiskLevel level) {
  switch (level) {
    case RiskLevel.tinggi:
      return AppColors.danger;
    case RiskLevel.sedang:
      return AppColors.warn;
    case RiskLevel.rendah:
      return AppColors.safe;
  }
}

String two(int n) => n.toString().padLeft(2, '0');

String hhmm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

/// Kartu putih berborder, gaya `Card` di web.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor ?? AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: kSerif,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Label kecil berwarna (level risiko, status alert).
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Angka vital dengan ikon, label, dan satuan.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.accentDark;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSerif,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: color ?? AppColors.ink,
                    height: 1,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Grafik garis detak jantung dari data vital (waktu di sumbu X).
class HeartRateChart extends StatelessWidget {
  const HeartRateChart({super.key, required this.points, this.height = 170});

  final List<VitalPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final data = points.where((p) => p.heartRate != null).toList();

    if (data.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'Belum ada data detak jantung dalam 6 jam terakhir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Grafik detak jantung 6 jam terakhir',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _HeartRatePainter(data)),
      ),
    );
  }
}

class _HeartRatePainter extends CustomPainter {
  _HeartRatePainter(this.data);

  final List<VitalPoint> data;

  static const double _left = 36;
  static const double _right = 8;
  static const double _top = 8;
  static const double _bottom = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );

    final values = data.map((p) => p.heartRate!).toList();
    var lo = values.reduce(math.min).toDouble() - 5;
    var hi = values.reduce(math.max).toDouble() + 5;
    if (hi - lo < 20) {
      final mid = (hi + lo) / 2;
      lo = mid - 10;
      hi = mid + 10;
    }

    final t0 = data.first.time.millisecondsSinceEpoch;
    final t1 = data.last.time.millisecondsSinceEpoch;
    final span = math.max(1, t1 - t0);

    double xOf(VitalPoint p) =>
        plot.left + (p.time.millisecondsSinceEpoch - t0) / span * plot.width;
    double yOf(num v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final value = lo + (hi - lo) * i / 2;
      final y = yOf(value);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _label(canvas, value.round().toString(), Offset(_left - 6, y),
          alignRight: true, centerY: true);
    }

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final p = data[i];
      final o = Offset(xOf(p), yOf(p.heartRate!));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final last = data.last;
    canvas.drawCircle(
      Offset(xOf(last), yOf(last.heartRate!)),
      4.5,
      Paint()..color = AppColors.accentDark,
    );

    _label(canvas, hhmm(data.first.time), Offset(plot.left, size.height - 16));
    _label(canvas, hhmm(data.last.time), Offset(plot.right, size.height - 16),
        alignRight: true);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool alignRight = false,
    bool centerY = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = alignRight ? anchor.dx - tp.width : anchor.dx;
    final dy = centerY ? anchor.dy - tp.height / 2 : anchor.dy;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _HeartRatePainter oldDelegate) =>
      oldDelegate.data != data;
}

/// Diagram batang aktivitas 7 hari (nilai 0-100).
class ActivityBars extends StatelessWidget {
  const ActivityBars({super.key, required this.days, this.height = 120});

  final List<ActivityDay> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'Belum ada data aktivitas.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return SizedBox(
      height: height + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: math.max(
                        4.0,
                        height * d.value.clamp(0, 100).toDouble() / 100,
                      ),
                      decoration: BoxDecoration(
                        color: d.value > 0
                            ? AppColors.accent
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.day,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
