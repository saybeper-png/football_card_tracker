import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/player_card_hub_model.dart';

class HexagonRadarChart extends StatefulWidget {
  final CardAttributes attributes;
  final CardAttributes? compareAttributes;
  final double size;
  final double maxValue;
  final Color primaryColor;
  final Color compareColor;
  final Color gridColor;

  const HexagonRadarChart({
    super.key,
    required this.attributes,
    this.compareAttributes,
    this.size = 260,
    this.maxValue = 99.0,
    this.primaryColor = const Color(0xFFFFD54F),
    this.compareColor = const Color(0xFF00E5FF),
    this.gridColor = const Color(0x33D4AF37),
  });

  @override
  State<HexagonRadarChart> createState() => _HexagonRadarChartState();
}

class _HexagonRadarChartState extends State<HexagonRadarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _animation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _RadarComparePainter(
            attributes: widget.attributes,
            compareAttributes: widget.compareAttributes,
            progress: _animation.value,
            maxValue: widget.maxValue,
            primaryColor: widget.primaryColor,
            compareColor: widget.compareColor,
            gridColor: widget.gridColor,
          ),
        );
      },
    );
  }
}

class _RadarComparePainter extends CustomPainter {
  final CardAttributes attributes;
  final CardAttributes? compareAttributes;
  final double progress;
  final double maxValue;
  final Color primaryColor;
  final Color compareColor;
  final Color gridColor;

  _RadarComparePainter({
    required this.attributes,
    this.compareAttributes,
    required this.progress,
    required this.maxValue,
    required this.primaryColor,
    required this.compareColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 34;
    const numAxes = 6;
    const angleStep = (2 * math.pi) / numAxes;
    const startAngle = -math.pi / 2;

    final stats1 = [
      _StatEntry('SPD', attributes.spd),
      _StatEntry('DRI', attributes.dri),
      _StatEntry('TEC', attributes.tec),
      _StatEntry('PAS', attributes.pas),
      _StatEntry('PWR', attributes.pwr),
      _StatEntry('WRK', attributes.wrk),
    ];

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (int level = 1; level <= 4; level++) {
      final levelRadius = radius * (level / 4);
      final gridPath = Path();
      for (int i = 0; i < numAxes; i++) {
        final angle = startAngle + i * angleStep;
        final p = Offset(center.dx + levelRadius * math.cos(angle),
            center.dy + levelRadius * math.sin(angle));
        if (i == 0) {
          gridPath.moveTo(p.dx, p.dy);
        } else {
          gridPath.lineTo(p.dx, p.dy);
        }
      }
      gridPath.close();
      canvas.drawPath(gridPath, gridPaint);
    }

    if (compareAttributes != null) {
      final stats2 = [
        _StatEntry('SPD', compareAttributes!.spd),
        _StatEntry('DRI', compareAttributes!.dri),
        _StatEntry('TEC', compareAttributes!.tec),
        _StatEntry('PAS', compareAttributes!.pas),
        _StatEntry('PWR', compareAttributes!.pwr),
        _StatEntry('WRK', compareAttributes!.wrk),
      ];
      _drawPolygon(canvas, center, radius, stats2, compareColor, 0.25, 1.8,
          numAxes, angleStep, startAngle);
    }

    _drawPolygon(canvas, center, radius, stats1, primaryColor, 0.35, 2.4,
        numAxes, angleStep, startAngle);

    for (int i = 0; i < numAxes; i++) {
      final angle = startAngle + i * angleStep;
      final labelCenter = Offset(center.dx + (radius + 22) * math.cos(angle),
          center.dy + (radius + 22) * math.sin(angle));
      final span = TextSpan(
        children: [
          TextSpan(
              text: '${stats1[i].label}\n',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70)),
          TextSpan(
              text: '${stats1[i].value}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: primaryColor)),
        ],
      );
      final tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(
          canvas,
          Offset(
              labelCenter.dx - tp.width / 2, labelCenter.dy - tp.height / 2));
    }
  }

  void _drawPolygon(
      Canvas canvas,
      Offset center,
      double radius,
      List<_StatEntry> stats,
      Color color,
      double fillAlpha,
      double strokeWidth,
      int numAxes,
      double angleStep,
      double startAngle) {
    final path = Path();
    for (int i = 0; i < numAxes; i++) {
      final angle = startAngle + i * angleStep;
      final curR =
          radius * (stats[i].value / maxValue).clamp(0.0, 1.0) * progress;
      final p = Offset(center.dx + curR * math.cos(angle),
          center.dy + curR * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: fillAlpha)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);
  }

  @override
  bool shouldRepaint(covariant _RadarComparePainter old) =>
      old.progress != progress || old.attributes != attributes;
}

class _StatEntry {
  final String label;
  final int value;
  _StatEntry(this.label, this.value);
}
