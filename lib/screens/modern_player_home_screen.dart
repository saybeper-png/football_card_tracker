import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/player_card_hub_model.dart';
import 'tactical_match_hub_screen.dart';

class ModernPlayerHomeScreen extends StatefulWidget {
  final PlayerCardHubModel player;
  final VoidCallback onOpenWorkout;
  final VoidCallback onRefresh;

  const ModernPlayerHomeScreen({
    super.key,
    required this.player,
    required this.onOpenWorkout,
    required this.onRefresh,
  });

  @override
  State<ModernPlayerHomeScreen> createState() => _ModernPlayerHomeScreenState();
}

class _ModernPlayerHomeScreenState extends State<ModernPlayerHomeScreen> {
  late DateTime _currentTime;
  Timer? _clockTimer;

  final List<Map<String, dynamic>> _quests = [
    {'title': 'Взрывной спринт 30м (3 серии)', 'xp': 25, 'isDone': true},
    {'title': 'Слалом с мячом вокруг конусов', 'xp': 20, 'isDone': true},
    {'title': 'Жонглирование мячом (50 раз)', 'xp': 15, 'isDone': true},
    {'title': 'Удары по воротам с ходу (10 раз)', 'xp': 25, 'isDone': false},
    {'title': 'Сдать видео разбора тренеру', 'xp': 50, 'isDone': false},
  ];

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  int get _completedQuestsCount => _quests.where((q) => q['isDone'] == true).length;

  void _toggleQuest(int index) {
    setState(() {
      _quests[index]['isDone'] = !(_quests[index]['isDone'] as bool);
    });
  }

  String _formatDate(DateTime dt) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    const weekdays = [
      'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'
    ];
    final weekday = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];
    return '$weekday, ${dt.day} $month ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final info = player.personalInfo;
    final stats = player.cardStats;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D12),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFCCFF00),
          onRefresh: () async => widget.onRefresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Шапка с датой и часами
                _buildLiveDateTimeHeader(),

                const SizedBox(height: 16),

                // 2. Карточка игрока (FUT Card)
                _buildFutCard(player, info, stats),

                const SizedBox(height: 20),

                // 3. Блок квестов с красным ядром и зелеными сегментами
                _buildDailyQuestsCard(),

                const SizedBox(height: 14),

                // ========================================================
                //  ВОТ СЮДА ВСТАВЛЯЕТСЯ КНОПКА ТАКТИЧЕСКОГО РАЗБОРА:
                // ========================================================
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: const Color(0xFFCCFF00),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFCCFF00), width: 1.4),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.analytics_rounded, size: 22),
                  label: const Text(
                    'ТАКТИЧЕСКИЙ РАЗБОР МАТЧА (PRO)',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.6),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const TacticalMatchHubScreen(isCoachRole: true),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),

                // 4. Кнопка сдачи норматива (была раньше)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCCFF00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                  ),
                  icon: const Icon(Icons.videocam_rounded, size: 24),
                  label: const Text(
                    'СДАТЬ ТРЕНИРОВОЧНЫЙ НОРМАТИВ',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                  ),
                  onPressed: widget.onOpenWorkout,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveDateTimeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14161F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCCFF00).withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFF00).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_today_rounded, color: Color(0xFFCCFF00), size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(_currentTime).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'ТРЕНИРОВОЧНЫЙ ДЕНЬ',
                    style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCCFF00).withValues(alpha: 0.5), width: 1.0),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFCCFF00),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(_currentTime),
                  style: const TextStyle(
                    color: Color(0xFFCCFF00),
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFutCard(PlayerCardHubModel player, PersonalInfo info, CardStats stats) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const RadialGradient(
          center: Alignment(-0.4, -0.4),
          radius: 1.2,
          colors: [Color(0xFF2C2411), Color(0xFF14120B), Color(0xFF0A0A0A)],
        ),
        border: Border.all(color: const Color(0xFFFFD54F), width: 2.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 18,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stats.ovr}',
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                Text(
                  info.position,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text('#${info.jerseyNumber ?? 10}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 20,
            child: CircleAvatar(
              radius: 46,
              backgroundColor: const Color(0xFFFFD54F).withValues(alpha: 0.2),
              backgroundImage: (info.avatarUrl != null && info.avatarUrl!.isNotEmpty)
                  ? NetworkImage(info.avatarUrl!)
                  : null,
              child: (info.avatarUrl == null || info.avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 50, color: Color(0xFFFFD54F))
                  : null,
            ),
          ),
          Positioned(
            bottom: 54,
            left: 20,
            right: 20,
            child: Text(
              '${info.firstName} ${info.lastName}'.trim().toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Positioned(
            bottom: 14,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatPill('SPD', stats.attributes.spd),
                _buildStatPill('DRI', stats.attributes.dri),
                _buildStatPill('TEC', stats.attributes.tec),
                _buildStatPill('PAS', stats.attributes.pas),
                _buildStatPill('PWR', stats.attributes.pwr),
                _buildStatPill('WRK', stats.attributes.wrk),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, int val) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text('$val', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 13, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildDailyQuestsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14161F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomPaint(
                size: const Size(78, 78),
                painter: SegmentedQuestCirclePainter(
                  totalSegments: 5,
                  completedSegments: _completedQuestsCount,
                  coreColor: const Color(0xFFE53935),
                  activeColor: const Color(0xFF00E676),
                  inactiveColor: const Color(0xFF1B3B2B),
                ),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: Center(
                    child: Column(
                      mainAxisSize: breathQuestTextSize,
                      children: [
                        Text(
                          '$_completedQuestsCount/5',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'КВЕСТОВ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ЕЖЕДНЕВНЫЕ КВЕСТЫ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _completedQuestsCount == 5
                          ? '🎉 Все 5 заданий выполнены! +135 XP'
                          : 'Выполни 5 заданий, чтобы замкнуть зеленое кольцо',
                      style: TextStyle(
                        color: _completedQuestsCount == 5 ? const Color(0xFF00E676) : Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          ...List.generate(_quests.length, (i) {
            final q = _quests[i];
            final isDone = q['isDone'] as bool;
            return InkWell(
              onTap: () => _toggleQuest(i),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isDone ? const Color(0xFF00E676) : Colors.white30,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        q['title'] as String,
                        style: TextStyle(
                          color: isDone ? Colors.white : Colors.white70,
                          fontSize: 12,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: const Color(0xFF00E676),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${q['xp']} XP',
                        style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static const MainAxisSize breathQuestTextSize = MainAxisSize.min;
}

class SegmentedQuestCirclePainter extends CustomPainter {
  final int totalSegments;
  final int completedSegments;
  final Color coreColor;
  final Color activeColor;
  final Color inactiveColor;

  SegmentedQuestCirclePainter({
    required this.totalSegments,
    required this.completedSegments,
    required this.coreColor,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const strokeWidth = 6.0;
    final outerRingRadius = radius - strokeWidth / 2;
    const gapAngle = 0.16;
    final segmentSweep = (2 * math.pi - (totalSegments * gapAngle)) / totalSegments;
    const startAngleBase = -math.pi / 2 + (gapAngle / 2);

    final paintSegment = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < totalSegments; i++) {
      final startAngle = startAngleBase + i * (segmentSweep + gapAngle);
      final isCompleted = i < completedSegments;

      paintSegment.color = isCompleted ? activeColor : inactiveColor;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRingRadius),
        startAngle,
        segmentSweep,
        false,
        paintSegment,
      );
    }

    final coreRadius = outerRingRadius - strokeWidth / 2 - 4.5;
    final paintCore = Paint()
      ..color = coreColor
      ..style = PaintingStyle.fill;

    final paintGlow = Paint()
      ..color = coreColor.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, coreRadius, paintGlow);
    canvas.drawCircle(center, coreRadius, paintCore);
  }

  @override
  bool shouldRepaint(covariant SegmentedQuestCirclePainter oldDelegate) {
    return oldDelegate.completedSegments != completedSegments ||
        oldDelegate.totalSegments != totalSegments;
  }
}
