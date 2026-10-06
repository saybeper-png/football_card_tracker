import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConfettiParticle {
  late double x, y, vx, vy, size, rotation, rotationSpeed;
  late Color color;

  ConfettiParticle({required Size origin}) {
    final r = math.Random();
    x = origin.width / 2;
    y = origin.height * 0.45;
    final angle = r.nextDouble() * 2 * math.pi;
    final speed = r.nextDouble() * 450 + 200;
    vx = math.cos(angle) * speed;
    vy = math.sin(angle) * speed - 150;
    size = r.nextDouble() * 7 + 4;
    rotation = r.nextDouble() * math.pi;
    rotationSpeed = (r.nextDouble() - 0.5) * 12;
    const colors = [Color(0xFFFFD700), Color(0xFFFFA000), Color(0xFF00E5FF), Color(0xFFFFFFFF), Color(0xFFFF3D00)];
    color = colors[r.nextInt(colors.length)];
  }

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 500 * dt;
    vx *= 0.96;
    rotation += rotationSpeed * dt;
  }
}

class FireworksPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double opacity;
  FireworksPainter({required this.particles, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    for (final p in particles) {
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        Paint()..color = p.color.withValues(alpha: opacity)..style = PaintingStyle.fill,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant FireworksPainter old) => true;
}