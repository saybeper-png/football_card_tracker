import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'in_app_video_player.dart';

class WorkoutType {
  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final int xp;
  final String statKey;
  final String statName;
  final Color color;
  final String videoUrl;
  final List<String> techniqueRules;
  final List<String> commonMistakes;

  const WorkoutType({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.xp,
    required this.statKey,
    required this.statName,
    required this.color,
    required this.videoUrl,
    required this.techniqueRules,
    required this.commonMistakes,
  });
}

class LogWorkoutSheet extends StatefulWidget {
  final String playerId;
  final VoidCallback onSaved;

  const LogWorkoutSheet({
    super.key,
    required this.playerId,
    required this.onSaved,
  });

  @override
  State<LogWorkoutSheet> createState() => _LogWorkoutSheetState();
}

class _LogWorkoutSheetState extends State<LogWorkoutSheet> {
  bool _isSaving = false;

  final workouts = const [
    WorkoutType(
      id: 'spd_sprint',
      title: 'Спринты и взрывной старт',
      subtitle: 'Челночный бег 5x20м, рывки со сменой вектора',
      emoji: '⚡',
      xp: 80,
      statKey: 'attr_spd',
      statName: '+1 SPD (Скорость)',
      color: Color(0xFF00E5FF),
      videoUrl:
          'https://bdmvnaeawsfzurvdzaml.supabase.co/storage/v1/object/public/drills/sprint.mp4',
      techniqueRules: [
        'Стартуй из полуприседа на носочках, корпус наклонен вперед под 45°',
        'Руки согнуты в локтях на 90° и работают мощно в противоход ногам',
        'Первые 3 шага — самые короткие и взрывные, толчок передней частью стопы',
      ],
      commonMistakes: [
        'Бег на полной стопе или пятках (теряется до 30% взрывной силы)',
        'Выпрямление корпуса на первых метрах старта',
      ],
    ),
    WorkoutType(
      id: 'dri_slalom',
      title: 'Дриблинг и контроль мяча',
      subtitle: 'Слалом вокруг конусов, ведение внешней стороной',
      emoji: '🎯',
      xp: 75,
      statKey: 'attr_dri',
      statName: '+1 DRI (Дриблинг)',
      color: Color(0xFFFFD54F),
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      techniqueRules: [
        'Касание мяча каждым шагом, мяч не отлетает дальше 30–40 см',
        'Веди мяч внешней частью подъема стопы, колени мягкие и согнутые',
        'Поднимай подбородок: смотри на пространство вокруг, а не только под ноги',
      ],
      commonMistakes: [
        'Слишком сильный толчок мяча вперед с потерей темпа шага',
        'Прямые напряженные колени при смене направления',
      ],
    ),
    WorkoutType(
      id: 'pwr_shot',
      title: 'Удары по воротам на силу и точность',
      subtitle: 'Удары подъемом с лета и с ведения мяча',
      emoji: '💥',
      xp: 70,
      statKey: 'attr_pwr',
      statName: '+1 PWR (Сила удара)',
      color: Color(0xFFFF5252),
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      techniqueRules: [
        'Опорная нога ставится строго на одной линии с мячом в 10–15 см сбоку',
        'Носок бьющей ноги оттянут вниз, голеностоп жестко зафиксирован (удар шнурками)',
        'Корпус слегка наклонен над мячом — это удержит удар низом или на средней высоте',
      ],
      commonMistakes: [
        'Откидывание плеч назад в момент удара (из-за этого мяч летит выше ворот)',
        'Расслабленная, «мягкая» стопа при касании мяча',
      ],
    ),
  ];

  void _showTechniqueModal(WorkoutType workout) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF161926),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(workout.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        workout.statName,
                        style: TextStyle(
                          color: workout.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InAppVideoPlayer(videoUrl: workout.videoUrl),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('✅', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 6),
                        Text(
                          'ПРАВИЛА ИДЕАЛЬНОЙ ТЕХНИКИ',
                          style: TextStyle(
                            color: Color(0xFF58CC02),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...workout.techniqueRules.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                color: Color(0xFF58CC02),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                r,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Text('❌', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 6),
                        Text(
                          'ЧАСТЫЕ ОШИБКИ (ИЗБЕГАЙ)',
                          style: TextStyle(
                            color: Color(0xFFFF5252),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...workout.commonMistakes.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                color: Color(0xFFFF5252),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                m,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _logWorkout(workout);
                },
                child: Text(
                  'ВЫПОЛНИЛ ПО ТЕХНИКЕ (+${workout.xp} XP)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logWorkout(WorkoutType workout) async {
    setState(() => _isSaving = true);
    final supabase = Supabase.instance.client;

    try {
      final res = await supabase
          .from('player_profiles')
          .select()
          .eq('user_id', widget.playerId)
          .single();

      final currentTotalXp = ((res['total_xp'] as num?) ?? 0).toInt();
      final currentSpendable = ((res['spendable_xp'] as num?) ?? 0).toInt();
      final currentStreak = ((res['current_streak'] as num?) ?? 0).toInt();
      final maxStreak = ((res['max_streak'] as num?) ?? 0).toInt();
      final currentStat = ((res[workout.statKey] as num?) ?? 50).toInt();

      final newTotalXp = currentTotalXp + workout.xp;
      final newSpendable = currentSpendable + workout.xp;
      final newLevel = 1 + (newTotalXp ~/ 500);
      final newStreak = currentStreak + 1;
      final newMaxStreak = max(maxStreak, newStreak);
      final newStat = min(99, currentStat + 1);

      await supabase.from('player_profiles').update({
        'total_xp': newTotalXp,
        'spendable_xp': newSpendable,
        'level': newLevel,
        'current_streak': newStreak,
        'max_streak': newMaxStreak,
        workout.statKey: newStat,
      }).eq('user_id', widget.playerId);

      HapticFeedback.heavyImpact();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B1D26),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              Text(workout.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+${workout.xp} XP получено! 🏆',
                      style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Характеристика: ${workout.statName}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.red, content: Text('Ошибка записи: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF141620),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Text('⚽', style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Text(
                  'ВЫБЕРИ УПРАЖНЕНИЕ',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      fontSize: 15,
                      color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Нажми «Видео и техника» для просмотра разбора внутри приложения:',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Color(0xFFFFD54F)),
                ),
              )
            else
              ...workouts.map((w) => _buildWorkoutCard(w)),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(WorkoutType w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: w.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(w.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(w.subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${w.xp} XP',
                  style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w900,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E5FF),
                    side:
                        const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => _showTechniqueModal(w),
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Видео и техника',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () => _logWorkout(w),
                child: const Text('Зачесть ✓',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
