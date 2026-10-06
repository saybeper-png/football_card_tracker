import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DuoMascotBubble extends StatefulWidget {
  final String playerName;
  final int streakDays;
  final int ovr;

  const DuoMascotBubble({
    super.key,
    required this.playerName,
    required this.streakDays,
    required this.ovr,
  });

  @override
  State<DuoMascotBubble> createState() => _DuoMascotBubbleState();
}

class _DuoMascotBubbleState extends State<DuoMascotBubble> {
  int _tipIndex = 0;

  final List<String> _tips = [
    'Серия {streak} дн. без пропусков! Тренируйся сегодня, чтобы не сгорел огонь 🔥',
    'Совет дня: перед ударом ставь опорную ногу строго на одной линии с мячом ⚽',
    'Твой общий рейтинг OVR {ovr}! Ещё пару тренировок — и возьмем карточку TOTW 🏆',
    'Не забывай пить воду мелкими глотками между скоростными челноками 💧',
    'Слалом вокруг конусов на носочках развивает взрывной дриблинг ⚡',
  ];

  void _nextTip() {
    HapticFeedback.lightImpact();
    setState(() {
      _tipIndex = (_tipIndex + 1) % _tips.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rawTip = _tips[_tipIndex];
    final message = rawTip
        .replaceAll('{streak}', widget.streakDays.toString())
        .replaceAll('{ovr}', widget.ovr.toString());

    return GestureDetector(
      onTap: _nextTip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161925),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Иконка-маскот тренера
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFF9600).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF9600), width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Text('🦊', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            // Речевой пузырь (Speech Bubble)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'ТРЕНЕР ФОКСИ',
                        style: TextStyle(
                          color: Color(0xFFFF9600),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'нажми для совета 💬',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
