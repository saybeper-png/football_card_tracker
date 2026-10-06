import 'dart:math' as math;
import 'package:flutter/material.dart';

class ElectricLightningBorder extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final Color lightningColor;
  final double intensity;
  final bool isEnabled;

  const ElectricLightningBorder({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.lightningColor = const Color(0xFF00E5FF),
    this.intensity = 5.0,
    this.isEnabled = true,
  });

  @override
  State<ElectricLightningBorder> createState() => _ElectricLightningBorderState();
}

class _ElectricLightningBorderState extends State<ElectricLightningBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        foregroundPainter: _LightningPainter(
          borderRadius: widget.borderRadius,
          color: widget.lightningColor,
          intensity: widget.intensity,
          seed: DateTime.now().microsecondsSinceEpoch,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _LightningPainter extends CustomPainter {
  final double borderRadius;
  final Color color;
  final double intensity;
  final int seed;

  _LightningPainter({required this.borderRadius, required this.color, required this.intensity, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final random = math.Random(seed);
    final basePath = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(borderRadius)));
    final metric = basePath.computeMetrics().first;
    final totalLength = metric.length;
    const segmentLength = 10.0;
    final numSegments = (totalLength / segmentLength).floor();

    final path = Path();
    bool isFirst = true;

    for (int i = 0; i <= numSegments; i++) {
      final tangent = metric.getTangentForOffset((i * segmentLength).clamp(0.0, totalLength));
      if (tangent == null) continue;
      final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
      final disp = (random.nextDouble() - 0.5) * 2.0 * intensity;
      final pt = tangent.position + (normal * disp);
      if (isFirst) { path.moveTo(pt.dx, pt.dy); isFirst = false; } else { path.lineTo(pt.dx, pt.dy); }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 9.0..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0));
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.0..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0));
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.3);
  }

  @override
  bool shouldRepaint(covariant _LightningPainter old) => true;
}