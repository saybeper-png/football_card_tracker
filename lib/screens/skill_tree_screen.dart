// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/player_card_hub_model.dart';

class SkillNode {
  final String id;
  final String title;
  final String subtitle;
  final String category; // speed, dribble, shot, pass
  final String emoji;
  final int tier; // 1, 2, 3
  final int xpCost;
  final String statBonusKey;
  final int statBonusVal;
  final String? prerequisiteId;
  final String videoUrl;
  final String tip;

  const SkillNode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.emoji,
    required this.tier,
    required this.xpCost,
    required this.statBonusKey,
    required this.statBonusVal,
    this.prerequisiteId,
    required this.videoUrl,
    required this.tip,
  });
}

class SkillTreeScreen extends StatefulWidget {
  final PlayerCardHubModel player;
  final VoidCallback onSkillUnlocked;

  const SkillTreeScreen({
    super.key,
    required this.player,
    required this.onSkillUnlocked,
  });

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> {
  String _selectedCategory = 'all';
  Set<String> _unlockedSkillIds = {};
  bool _isLoading = true;

  final List<SkillNode> _allSkills = const [
    // --- ВЕТКА: СКОРОСТЬ ⚡ ---
    SkillNode(
      id: 'spd_tier_1',
      category: 'speed',
      tier: 1,
      title: 'Взрывной старт',
      subtitle: 'Низкая посадка и первые 3 коротких шага',
      emoji: '⚡',
      xpCost: 150,
      statBonusKey: 'attr_spd',
      statBonusVal: 2,
      prerequisiteId: null,
      videoUrl:
          'https://www.youtube.com/results?search_query=explosive+first+step+soccer+drills',
      tip: 'Толчок идет строго носком опорной ноги под углом 45 градусов.',
    ),
    SkillNode(
      id: 'spd_tier_2',
      category: 'speed',
      tier: 2,
      title: 'Смена вектора',
      subtitle: 'Резкий стоп-энд-гоу со сменой направления',
      emoji: '🌪️',
      xpCost: 250,
      statBonusKey: 'attr_spd',
      statBonusVal: 3,
      prerequisiteId: 'spd_tier_1',
      videoUrl:
          'https://www.youtube.com/results?search_query=change+of+direction+speed+drills+football',
      tip: 'Понижай центр тяжести за полшага до смены траектории.',
    ),
    SkillNode(
      id: 'spd_tier_3',
      category: 'speed',
      tier: 3,
      title: 'Турбо-спринт 30м',
      subtitle: 'Максимальная дистанционная скорость в контратаке',
      emoji: '🚀',
      xpCost: 400,
      statBonusKey: 'attr_spd',
      statBonusVal: 4,
      prerequisiteId: 'spd_tier_2',
      videoUrl:
          'https://www.youtube.com/results?search_query=sprint+mechanics+soccer+speed',
      tip: 'Плечи расслаблены, руки работают широко в противоход бедрам.',
    ),

    // --- ВЕТКА: ДРИБЛИНГ 🎯 ---
    SkillNode(
      id: 'dri_tier_1',
      category: 'dribble',
      tier: 1,
      title: 'Мяч на привязи',
      subtitle: 'Ведение внешней стороной подъема каждым шагом',
      emoji: '🎯',
      xpCost: 150,
      statBonusKey: 'attr_dri',
      statBonusVal: 2,
      prerequisiteId: null,
      videoUrl:
          'https://www.youtube.com/results?search_query=close+control+dribbling+kids',
      tip: 'Мяч не должен отлетать дальше полуметра от ведущей стопы.',
    ),
    SkillNode(
      id: 'dri_tier_2',
      category: 'dribble',
      tier: 2,
      title: 'Финт Зидана (Roulette)',
      subtitle: 'Разворот на 360 с прокатом подошвой',
      emoji: '🔄',
      xpCost: 250,
      statBonusKey: 'attr_dri',
      statBonusVal: 3,
      prerequisiteId: 'dri_tier_1',
      videoUrl:
          'https://www.youtube.com/results?search_query=zidane+roulette+tutorial+kids',
      tip: 'Первое касание укрывает мяч корпусом от защитника.',
    ),
    SkillNode(
      id: 'dri_tier_3',
      category: 'dribble',
      tier: 3,
      title: 'Эластико (Роналдиньо)',
      subtitle: 'Взрывной обман внешняя-внутренняя за доли секунды',
      emoji: '🪄',
      xpCost: 400,
      statBonusKey: 'attr_dri',
      statBonusVal: 4,
      prerequisiteId: 'dri_tier_2',
      videoUrl:
          'https://www.youtube.com/results?search_query=elastico+tutorial+soccer',
      tip: 'Ключ — в гибкости голеностопа и резком смещении плеч.',
    ),

    // --- ВЕТКА: УДАРЫ 💥 ---
    SkillNode(
      id: 'pwr_tier_1',
      category: 'shot',
      tier: 1,
      title: 'Прицел в угол',
      subtitle: 'Удар щечкой с подкруткой под дальнюю штангу',
      emoji: '🎯',
      xpCost: 150,
      statBonusKey: 'attr_pwr',
      statBonusVal: 2,
      prerequisiteId: null,
      videoUrl:
          'https://www.youtube.com/results?search_query=curl+shot+inside+foot+tutorial',
      tip: 'Опорная нога смотрит чуть в сторону от цели для закрутки.',
    ),
    SkillNode(
      id: 'pwr_tier_2',
      category: 'shot',
      tier: 2,
      title: 'Пушечный подъем',
      subtitle: 'Плотный хлесткий удар центром шнурков на силу',
      emoji: '💥',
      xpCost: 250,
      statBonusKey: 'attr_pwr',
      statBonusVal: 3,
      prerequisiteId: 'pwr_tier_1',
      videoUrl:
          'https://www.youtube.com/results?search_query=laces+strike+shooting+power+soccer',
      tip: 'Носок жестко натянут в землю, корпус накрывает мяч сверху.',
    ),
    SkillNode(
      id: 'pwr_tier_3',
      category: 'shot',
      tier: 3,
      title: 'Штрафной Наклбол',
      subtitle: 'Удар без вращения с непредсказуемой траекторией',
      emoji: '☄️',
      xpCost: 400,
      statBonusKey: 'attr_pwr',
      statBonusVal: 4,
      prerequisiteId: 'pwr_tier_2',
      videoUrl:
          'https://www.youtube.com/results?search_query=knuckleball+tutorial+football',
      tip: 'Короткий акцентированный удар костью стопы без проводки ноги.',
    ),

    // --- ВЕТКА: ПАСЫ 📐 ---
    SkillNode(
      id: 'pas_tier_1',
      category: 'pass',
      tier: 1,
      title: 'Стенка в касание',
      subtitle: 'Быстрый отыгрыш в одно касание на ход партнеру',
      emoji: '📐',
      xpCost: 150,
      statBonusKey: 'attr_pas',
      statBonusVal: 2,
      prerequisiteId: null,
      videoUrl:
          'https://www.youtube.com/results?search_query=give+and+go+one+two+pass+soccer',
      tip: 'Отдал пас — сразу делай рывок в свободную зону.',
    ),
    SkillNode(
      id: 'pas_tier_2',
      category: 'pass',
      tier: 2,
      title: 'Диагональ верхом',
      subtitle: 'Перевод игры на противоположный фланг подсечкой',
      emoji: '🌐',
      xpCost: 250,
      statBonusKey: 'attr_pas',
      statBonusVal: 3,
      prerequisiteId: 'pas_tier_1',
      videoUrl:
          'https://www.youtube.com/results?search_query=long+diagonal+passing+technique+soccer',
      tip: 'Подсекай мяч нижней частью стопы, отклоняя корпус назад.',
    ),
    SkillNode(
      id: 'pas_tier_3',
      category: 'pass',
      tier: 3,
      title: 'Разрезающий пас',
      subtitle: 'Тонкая скрытая передача между двумя защитниками',
      emoji: '👑',
      xpCost: 400,
      statBonusKey: 'attr_pas',
      statBonusVal: 4,
      prerequisiteId: 'pas_tier_2',
      videoUrl:
          'https://www.youtube.com/results?search_query=through+ball+vision+passing+drills',
      tip: 'Смотри в одну сторону, а передачу отдавай в другую (No-look).',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnlockedSkills();
  }

  Future<void> _loadUnlockedSkills() async {
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('player_skills')
          .select('skill_id')
          .eq('player_id', widget.player.playerId);

      final ids = (res as List).map((e) => e['skill_id'].toString()).toSet();
      if (mounted) {
        setState(() {
          _unlockedSkillIds = ids;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlockSkill(SkillNode skill) async {
    final currentXp = widget.player.cardStats.totalXp;
    if (currentXp < skill.xpCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
              'Нужно еще ${skill.xpCost - currentXp} XP! Проведи тренировку ⚽'),
        ),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // 1. Записываем разблокировку в таблицу
      await supabase.from('player_skills').insert({
        'player_id': widget.player.playerId,
        'skill_id': skill.id,
      });

      // 2. Списываем XP и добавляем бонус к характеристике
      final profile = await supabase
          .from('player_profiles')
          .select()
          .eq('user_id', widget.player.playerId)
          .single();

      final curStat = ((profile[skill.statBonusKey] as num?) ?? 50).toInt();
      final curSpendable = ((profile['spendable_xp'] as num?) ?? 0).toInt();

      await supabase.from('player_profiles').update({
        skill.statBonusKey: curStat + skill.statBonusVal,
        'spendable_xp': (curSpendable - skill.xpCost).clamp(0, 999999),
      }).eq('user_id', widget.player.playerId);

      HapticFeedback.heavyImpact();

      setState(() => _unlockedSkillIds.add(skill.id));
      widget.onSkillUnlocked();

      if (!mounted) return;
      Navigator.pop(context); // закрываем диалог

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1B1D28),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('НАВЫК РАЗБЛОКИРОВАН! 🏆',
              style: TextStyle(
                  color: Color(0xFFFFD54F), fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(skill.emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(skill.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              const SizedBox(height: 6),
              Text('Бонус к карточке: +${skill.statBonusVal} к характеристике!',
                  style: const TextStyle(
                      color: Color(0xFF58CC02), fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('КРУТО!',
                  style: TextStyle(
                      color: Color(0xFFFFD54F), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: Colors.red,
            content: Text('Ошибка разблокировки: $e')),
      );
    }
  }

  void _showSkillModal(SkillNode skill, bool isUnlocked, bool canUnlock) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF161926),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? const Color(0xFF58CC02).withValues(alpha: 0.2)
                        : Colors.white10,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isUnlocked
                            ? const Color(0xFF58CC02)
                            : const Color(0xFFFFD54F),
                        width: 2),
                  ),
                  alignment: Alignment.center,
                  child:
                      Text(skill.emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(skill.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Colors.white)),
                      Text(
                          'Ранг ${skill.tier} • +${skill.statBonusVal} к характеристике',
                          style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(skill.subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(skill.tip,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final uri = Uri.parse(skill.videoUrl);
                if (await canLaunchUrl(uri))
                  launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE50914).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_circle_fill,
                        color: Color(0xFFE50914), size: 20),
                    SizedBox(width: 8),
                    Text('Видео разбор движения 🎬',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isUnlocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: const Color(0xFF58CC02).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: const Text('НАВЫК ОСВОЕН ✓',
                    style: TextStyle(
                        color: Color(0xFF58CC02),
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canUnlock ? const Color(0xFFFFD54F) : Colors.white10,
                    foregroundColor: canUnlock ? Colors.black : Colors.white30,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: canUnlock ? () => _unlockSkill(skill) : null,
                  child: Text(
                    canUnlock
                        ? 'ИЗУЧИТЬ ЗА ${skill.xpCost} XP'
                        : 'СНАЧАЛА ИЗУЧИ ПРЕДЫДУЩИЙ РАНГ 🔒',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSkills = _selectedCategory == 'all'
        ? _allSkills
        : _allSkills.where((s) => s.category == _selectedCategory).toList();

    final unlockedCount =
        _allSkills.where((s) => _unlockedSkillIds.contains(s.id)).length;
    final totalCount = _allSkills.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('ДЕРЕВО НАВЫКОВ',
            style: TextStyle(
                fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF58CC02).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF58CC02)),
            ),
            child: Text('$unlockedCount / $totalCount РАЗБЛОКИРОВАНО',
                style: const TextStyle(
                    color: Color(0xFF58CC02),
                    fontWeight: FontWeight.w900,
                    fontSize: 11)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD54F)))
          : Column(
              children: [
                _buildCategoryFilter(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: filteredSkills.length,
                    itemBuilder: (ctx, i) {
                      final skill = filteredSkills[i];
                      final isUnlocked = _unlockedSkillIds.contains(skill.id);
                      final canUnlock = skill.prerequisiteId == null ||
                          _unlockedSkillIds.contains(skill.prerequisiteId);

                      return _buildSkillTreeTile(skill, isUnlocked, canUnlock,
                          i < filteredSkills.length - 1);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryFilter() {
    final cats = [
      {'id': 'all', 'label': 'Все ветки 🌳'},
      {'id': 'speed', 'label': 'Скорость ⚡'},
      {'id': 'dribble', 'label': 'Дриблинг 🎯'},
      {'id': 'shot', 'label': 'Удары 💥'},
      {'id': 'pass', 'label': 'Пасы 📐'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: cats.map((c) {
          final isSel = _selectedCategory == c['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c['label']!,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSel ? Colors.black : Colors.white70)),
              selected: isSel,
              selectedColor: const Color(0xFFFFD54F),
              backgroundColor: const Color(0xFF161926),
              onSelected: (_) => setState(() => _selectedCategory = c['id']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkillTreeTile(
      SkillNode skill, bool isUnlocked, bool canUnlock, bool hasNext) {
    Color nodeColor = Colors.white24;
    if (isUnlocked) {
      nodeColor = const Color(0xFF58CC02);
    } else if (canUnlock) nodeColor = const Color(0xFFFFD54F);

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showSkillModal(skill, isUnlocked, canUnlock),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161926),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: nodeColor.withValues(alpha: 0.4),
                  width: isUnlocked ? 2 : 1.2),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: nodeColor.withValues(alpha: 0.15),
                        border: Border.all(color: nodeColor, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(skill.emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
                    if (!canUnlock && !isUnlocked)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.lock,
                            color: Colors.white70, size: 20),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(skill.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14)),
                          const Spacer(),
                          Text(
                            isUnlocked ? 'ОСВОЕНО' : '${skill.xpCost} XP',
                            style: TextStyle(
                              color: isUnlocked
                                  ? const Color(0xFF58CC02)
                                  : const Color(0xFFFFD54F),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(skill.subtitle,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasNext)
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? const Color(0xFF58CC02).withValues(alpha: 0.5)
                  : Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

