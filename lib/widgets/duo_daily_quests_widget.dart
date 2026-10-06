import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyQuestItem {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  int current;
  final int target;
  final int rewardXp;
  bool isCompleted;

  DailyQuestItem({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.target,
    required this.rewardXp,
    this.isCompleted = false,
  });
}

class DuoDailyQuestsWidget extends StatefulWidget {
  final String playerId;
  final VoidCallback onQuestCompleted;

  const DuoDailyQuestsWidget({
    super.key,
    required this.playerId,
    required this.onQuestCompleted,
  });

  @override
  State<DuoDailyQuestsWidget> createState() => _DuoDailyQuestsWidgetState();
}

class _DuoDailyQuestsWidgetState extends State<DuoDailyQuestsWidget> {
  late List<DailyQuestItem> _quests;

  @override
  void initState() {
    super.initState();
    _quests = [
      DailyQuestItem(
        id: 'quest_warmup',
        emoji: '🧘',
        title: 'Утренняя разминка или скакалка',
        subtitle: '10 мин на разогрев связок и стопы',
        current: 1,
        target: 1,
        rewardXp: 40,
        isCompleted: true,
      ),
      DailyQuestItem(
        id: 'quest_juggling',
        emoji: '⚽',
        title: 'Чеканка мяча (100 набиваний)',
        subtitle: 'Контроль мяча подъемом и бедром',
        current: 60,
        target: 100,
        rewardXp: 70,
        isCompleted: false,
      ),
      DailyQuestItem(
        id: 'quest_sprint',
        emoji: '⚡',
        title: 'Челночный бег 5 x 20 метров',
        subtitle: 'Стартовая взрывная скорость',
        current: 0,
        target: 5,
        rewardXp: 80,
        isCompleted: false,
      ),
    ];
  }

  Future<void> _completeQuest(DailyQuestItem quest) async {
    if (quest.isCompleted) return;

    setState(() {
      quest.current = quest.target;
      quest.isCompleted = true;
    });

    HapticFeedback.heavyImpact();

    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('player_profiles')
          .select('total_xp, spendable_xp')
          .eq('user_id', widget.playerId)
          .single();

      final currentTotal = ((res['total_xp'] as num?) ?? 0).toInt();
      final currentSpendable = ((res['spendable_xp'] as num?) ?? 0).toInt();

      await supabase.from('player_profiles').update({
        'total_xp': currentTotal + quest.rewardXp,
        'spendable_xp': currentSpendable + quest.rewardXp,
      }).eq('user_id', widget.playerId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B1D26),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Квест выполнен! +${quest.rewardXp} XP 💎',
                      style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold),
                    ),
                    Text(quest.title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      widget.onQuestCompleted();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Ошибка сохранения: $e')),
      );
    }
  }

  void _incrementProgress(DailyQuestItem quest, int step) {
    if (quest.isCompleted) return;

    setState(() {
      quest.current = min(quest.target, quest.current + step);
    });

    if (quest.current >= quest.target) {
      _completeQuest(quest);
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _quests.where((q) => q.isCompleted).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141620),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🎯', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'КВЕСТЫ ДНЯ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF58CC02).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF58CC02), width: 1),
                ),
                child: Text(
                  '$completedCount/${_quests.length} ГОТОВО',
                  style: const TextStyle(
                    color: Color(0xFF58CC02),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._quests.map((q) => _buildQuestTile(q)),
        ],
      ),
    );
  }

  Widget _buildQuestTile(DailyQuestItem q) {
    final progress = (q.current / q.target).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: q.isCompleted
              ? const Color(0xFF58CC02).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(q.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.title,
                      style: TextStyle(
                        color: q.isCompleted ? Colors.white54 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: q.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(q.subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (q.isCompleted)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF58CC02),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (q.target == 1) {
                      _completeQuest(q);
                    } else {
                      final step = q.target > 10 ? 20 : 1;
                      _incrementProgress(q, step);
                    }
                  },
                  child: Text(
                    q.target == 1 ? 'Завершить' : '+${q.target > 10 ? 20 : 1}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: q.isCompleted
                                ? [const Color(0xFF58CC02), const Color(0xFF69F0AE)]
                                : [const Color(0xFFFF9600), const Color(0xFFFFD54F)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${q.current}/${q.target}',
                style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '+${q.rewardXp} XP',
                style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
