// ignore_for_file: prefer_const_constructors
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/tactical_analysis_model.dart';

class PitchRadarWidget extends StatelessWidget {
  final List<TacticalEvent> events;
  final TacticalEvent? selectedEvent;
  final ValueChanged<TacticalEvent>? onEventSelected;
  final ValueChanged<Offset>? onPitchTapped;
  final bool isCoachMode;

  const PitchRadarWidget({
    super.key,
    required this.events,
    this.selectedEvent,
    this.onEventSelected,
    this.onPitchTapped,
    this.isCoachMode = false,
  });

  Color _getEventColor(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'goal':
      case 'shot':
        return const Color(0xFFCCFF00); // Неоновый салатовый
      case 'key_pass':
        return const Color(0xFF38BDF8); // Голубой
      case 'pressing':
      case 'duel_1v1':
        return const Color(0xFFFFB703); // Янтарный
      case 'turnover_lost':
        return const Color(0xFFEF4444); // Красный
      default:
        return const Color(0xFFA855F7); // Фиолетовый
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'goal':
      case 'shot':
        return Icons.sports_soccer;
      case 'key_pass':
        return Icons.arrow_forward_rounded;
      case 'pressing':
      case 'duel_1v1':
        return Icons.flash_on_rounded;
      case 'turnover_lost':
        return Icons.close_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCoachMode ? const Color(0xFFCCFF00) : Colors.white12,
          width: isCoachMode ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        // Стандартные пропорции футбольного поля (105м x 68м ≈ 1.54)
        aspectRatio: 1.54,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: isCoachMode && onPitchTapped != null
                  ? (details) {
                      final local = details.localPosition;
                      final normX = (local.dx / w).clamp(0.0, 1.0);
                      final normY = (local.dy / h).clamp(0.0, 1.0);
                      onPitchTapped!(Offset(normX, normY));
                    }
                  : null,
              child: Stack(
                children: [
                  // 1. Отрисовка газона и тактической разметки поля
                  CustomPaint(
                    size: Size(w, h),
                    painter: _TacticalPitchPainter(),
                  ),

                  // 2. Индикатор режима тренера (если включен)
                  if (isCoachMode)
                    Positioned(
                      top: 8,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFF00),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded, color: Colors.black, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'ТАПНИТЕ НА ПОЛЕ ДЛЯ ОТМЕТКИ',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Маркеры событий матча
                  ...events.map((event) {
                    final isSelected = selectedEvent?.id == event.id;
                    final color = _getEventColor(event.eventType);
                    final icon = _getEventIcon(event.eventType);

                    final posX = event.pitchX * w;
                    final posY = event.pitchY * h;

                    return Positioned(
                      left: posX - 15,
                      top: posY - 15,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => onEventSelected?.call(event),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 34 : 26,
                          height: isSelected ? 34 : 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.black87,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: isSelected ? 0.8 : 0.4),
                                blurRadius: isSelected ? 12 : 6,
                                spreadRadius: isSelected ? 2 : 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            size: isSelected ? 18 : 13,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    );
                  }),

                  // 4. Плашка выбранного момента
                  if (selectedEvent != null)
                    Positioned(
                      bottom: 8,
                      left: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getEventColor(selectedEvent!.eventType),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getEventIcon(selectedEvent!.eventType),
                              color: _getEventColor(selectedEvent!.eventType),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedEvent!.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(selectedEvent!.startMs ~/ 1000) ~/ 60}:${((selectedEvent!.startMs ~/ 1000) % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Высокоточная отрисовка футбольного поля по стандартам FIFA
class _TacticalPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Фоновая трава (чередующиеся полосы)
    final bgPaint = Paint()..color = const Color(0xFF0A1F1A);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final stripePaint = Paint()..color = const Color(0xFF0D2821);
    const stripeCount = 10;
    final stripeWidth = w / stripeCount;
    for (int i = 0; i < stripeCount; i += 2) {
      canvas.drawRect(Rect.fromLTWH(i * stripeWidth, 0, stripeWidth, h), stripePaint);
    }

    // Линии разметки
    final linePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    const pad = 8.0; // отступ от краев
    final fieldRect = Rect.fromLTRB(pad, pad, w - pad, h - pad);

    // 1. Внешний периметр
    canvas.drawRect(fieldRect, linePaint);

    // 2. Центральная линия и круг
    final midX = w / 2;
    canvas.drawLine(Offset(midX, pad), Offset(midX, h - pad), linePaint);

    final centerCircleRadius = h * 0.18;
    canvas.drawCircle(Offset(midX, h / 2), centerCircleRadius, linePaint);
    canvas.drawCircle(Offset(midX, h / 2), 2.5, linePaint..style = PaintingStyle.fill);
    linePaint.style = PaintingStyle.stroke;

    // 3. Штрафные площади (Penalty Area)
    final boxW = w * 0.16;
    final boxH = h * 0.58;
    final boxTop = (h - boxH) / 2;

    // Левая штрафная
    canvas.drawRect(Rect.fromLTWH(pad, boxTop, boxW, boxH), linePaint);
    // Правая штрафная
    canvas.drawRect(Rect.fromLTWH(w - pad - boxW, boxTop, boxW, boxH), linePaint);

    // 4. Вратарские площади (Goal Area)
    final goalBoxW = w * 0.055;
    final goalBoxH = h * 0.28;
    final goalBoxTop = (h - goalBoxH) / 2;

    canvas.drawRect(Rect.fromLTWH(pad, goalBoxTop, goalBoxW, goalBoxH), linePaint);
    canvas.drawRect(Rect.fromLTWH(w - pad - goalBoxW, goalBoxTop, goalBoxW, goalBoxH), linePaint);

    // 5. 11-метровые отметки (Penalty Spot)
    final penSpotDist = w * 0.11;
    canvas.drawCircle(Offset(pad + penSpotDist, h / 2), 2.0, linePaint..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(w - pad - penSpotDist, h / 2), 2.0, linePaint);
    linePaint.style = PaintingStyle.stroke;

    // 6. Угловые секторы
    const cornerR = 8.0;
    canvas.drawArc(Rect.fromCircle(center: Offset(pad, pad), radius: cornerR), 0, math.pi / 2, false, linePaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(pad, h - pad), radius: cornerR), -math.pi / 2, math.pi / 2, false, linePaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(w - pad, pad), radius: cornerR), math.pi / 2, math.pi / 2, false, linePaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(w - pad, h - pad), radius: cornerR), math.pi, math.pi / 2, false, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

