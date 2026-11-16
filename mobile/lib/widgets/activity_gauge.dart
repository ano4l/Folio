import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ActivityGauge extends StatelessWidget {
  final int documents;
  final int ready;
  final int attention;

  const ActivityGauge({
    super.key,
    required this.documents,
    required this.ready,
    required this.attention,
  });

  @override
  Widget build(BuildContext context) {
    final total = math.max(documents, 1);
    final readyValue = ready / total;
    final attentionValue = attention / total;
    final protectedValue = documents == 0 ? 0.0 : 1.0;

    return Semantics(
      label:
          'Vault activity. $documents documents, $ready ready, $attention need attention.',
      child: SizedBox.square(
        dimension: 188,
        child: CustomPaint(
          painter: _GaugePainter(
            progress: 1,
            values: [protectedValue, readyValue, attentionValue],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$documents',
                  style: const TextStyle(
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'vault files',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final List<double> values;
  const _GaugePainter({required this.progress, required this.values});

  static const colors = [AppColors.teal, AppColors.navy, AppColors.warning];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 10.0;
    const gap = 9.0;
    for (var index = 0; index < values.length; index++) {
      final radius =
          size.shortestSide / 2 - stroke / 2 - index * (stroke + gap);
      final rect = Rect.fromCircle(center: center, radius: radius);
      final background =
          Paint()
            ..color = AppColors.line.withValues(alpha: .55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round;
      final foreground =
          Paint()
            ..color = colors[index]
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, background);
      final sweep = math.pi * 2 * values[index].clamp(0, 1) * progress;
      if (sweep > 0) {
        canvas.drawArc(rect, -math.pi / 2, sweep, false, foreground);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    if (oldDelegate.progress != progress ||
        oldDelegate.values.length != values.length) {
      return true;
    }
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}
