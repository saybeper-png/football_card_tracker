import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tournament_standings_widget.dart';
import 'widgets/dynamic_block_renderer.dart';

class AcademyHubScreen extends StatefulWidget {
  final List<Map<String, dynamic>> dynamicBlocks;
  final String tournamentId;
  final String myTeamId;

  const AcademyHubScreen({
    super.key,
    required this.dynamicBlocks,
    this.tournamentId = 'a0000000-0000-0000-0000-000000000001',
    this.myTeamId = 'b0000000-0000-0000-0000-000000000001',
  });

  @override
  State<AcademyHubScreen> createState() => _AcademyHubScreenState();
}

class _AcademyHubScreenState extends State<AcademyHubScreen> {
  int _selectedTab = 0; // 0: Таблица, 1: Календарь, 2: Состав / Команды
  int _refreshCounter = 0;
  String? _activeTeamId;
  String? _activeTeamName;

  @override
  void initState() {
    super.initState();
    _activeTeamId = widget.myTeamId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0C0D12),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildTabSelector(),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildSelectedTabContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    final tabs = [
      {'title': 'Таблица', 'icon': Icons.emoji_events_outlined, 'selectedIcon': Icons.emoji_events},
      {'title': 'Календарь', 'icon': Icons.calendar_month_outlined, 'selectedIcon': Icons.calendar_month},
      {'title': 'Команды', 'icon': Icons.groups_outlined, 'selectedIcon': Icons.groups},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          final tab = tabs[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFB800) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFB800).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? (tab['selectedIcon'] as IconData) : (tab['icon'] as IconData),
                      size: 16,
                      color: isSelected ? Colors.black : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tab['title'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildStandingsTab();
      case 1:
        return _buildCalendarTab();
      case 2:
        return _buildRosterAndTeamsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStandingsTab() {
    return SingleChildScrollView(
      key: ValueKey('tab_standings_$_refreshCounter'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TournamentStandingsWidget(
            key: ValueKey('widget_standings_$_refreshCounter'),
            tournamentId: widget.tournamentId,
            title: 'Первенство U-10 • Золотая Лига',
            highlightTeamId: widget.myTeamId,
          ),
          const SizedBox(height: 16),
          if (widget.dynamicBlocks.isNotEmpty)
            DynamicBlockRenderer(blocks: widget.dynamicBlocks),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('tab_calendar_$_refreshCounter'),
      future: Supabase.instance.client
          .from('matches')
          .select('*, home:home_team_id(name, short_name), away:away_team_id(name, short_name)')
          .eq('tournament_id', widget.tournamentId)
          .order('match_date', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)));
        }

        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return const Center(
            child: Text(
              'Расписание матчей формируется',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: matches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final m = matches[index];
            final isFinished = m['status'] == 'finished';
            final homeTeam = (m['home'] as Map<String, dynamic>?)?['name'] ?? 'Хозяева';
            final awayTeam = (m['away'] as Map<String, dynamic>?)?['name'] ?? 'Гости';
            final scoreText = isFinished ? '${m['home_score']} : ${m['away_score']}' : 'VS';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF141724),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stadium_outlined, size: 14, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(
                            m['venue'] ?? 'Основной стадион',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isFinished
                                  ? Colors.white10
                                  : const Color(0xFFFFB800).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isFinished ? 'ЗАВЕРШЕН' : 'СКОРО',
                              style: TextStyle(
                                color: isFinished ? Colors.white60 : const Color(0xFFFFB800),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _openScoreEditDialog(m, homeTeam, awayTeam),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.edit_note,
                                color: Color(0xFFFFB800),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          homeTeam,
                          textAlign: TextAlign.end,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openScoreEditDialog(m, homeTeam, awayTeam),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isFinished
                                  ? const Color(0xFFFFB800).withValues(alpha: 0.4)
                                  : Colors.white12,
                            ),
                          ),
                          child: Text(
                            scoreText,
                            style: TextStyle(
                              color: isFinished ? const Color(0xFFFFB800) : Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          awayTeam,
                          textAlign: TextAlign.start,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openScoreEditDialog(Map<String, dynamic> match, String homeTeam, String awayTeam) {
    final homeController = TextEditingController(text: match['home_score']?.toString() ?? '0');
    final awayController = TextEditingController(text: match['away_score']?.toString() ?? '0');
    bool isFinished = match['status'] == 'finished' || match['status'] == null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141724),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Row(
            children: [
              Icon(Icons.sports_score, color: Color(0xFFFFB800)),
              SizedBox(width: 8),
              Text(
                'Результат матча',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          homeTeam,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: homeController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFFB800), fontSize: 24, fontWeight: FontWeight.w900),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black38,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(':', style: TextStyle(color: Colors.white38, fontSize: 26, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          awayTeam,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: awayController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFFB800), fontSize: 24, fontWeight: FontWeight.w900),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black38,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFFFFB800),
                title: const Text('Матч завершен', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: isFinished,
                onChanged: (val) => setDialogState(() => isFinished = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB800),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final hScore = int.tryParse(homeController.text.trim()) ?? 0;
                final aScore = int.tryParse(awayController.text.trim()) ?? 0;
                final newStatus = isFinished ? 'finished' : 'scheduled';
                final matchId = match['id'].toString();

                Navigator.of(ctx).pop();

                _updateMatchScore(
                  matchId: matchId,
                  homeScore: hScore,
                  awayScore: aScore,
                  status: newStatus,
                );
              },
              child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateMatchScore({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required String status,
  }) async {
    try {
      await Supabase.instance.client.from('matches').update({
        'home_score': homeScore,
        'away_score': awayScore,
        'status': status,
      }).eq('id', matchId);

      if (!mounted) return;
      setState(() => _refreshCounter++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Результат матча обновлен и таблица пересчитана!'),
          backgroundColor: Color(0xFF141724),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка обновления: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Вкладка 3: Команды и Составы
  Widget _buildRosterAndTeamsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('teams_list_$_refreshCounter'),
      future: Supabase.instance.client.from('teams').select('id, name, short_name').order('name'),
      builder: (context, teamSnapshot) {
        if (teamSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)));
        }

        final teams = teamSnapshot.data ?? [];
        if (teams.isNotEmpty && (_activeTeamId == null || !teams.any((t) => t['id'] == _activeTeamId))) {
          _activeTeamId = teams.first['id'].toString();
          _activeTeamName = teams.first['name'].toString();
        } else if (teams.isNotEmpty && _activeTeamId != null) {
          final current = teams.firstWhere((t) => t['id'] == _activeTeamId, orElse: () => teams.first);
          _activeTeamName = current['name']?.toString() ?? 'Команда';
        }

        return Column(
          children: [
            // Панель команд и кнопка "+ Создать команду"
            _buildTeamsBar(teams),
            const SizedBox(height: 8),
            // Состав активной команды
            Expanded(
              child: _activeTeamId == null
                  ? const Center(
                      child: Text('Создайте первую команду', style: TextStyle(color: Colors.white54)),
                    )
                  : _buildPlayersListForTeam(_activeTeamId!),
            ),
          ],
        );
      },
    );
  }

  // Горизонтальный список команд + кнопка добавления
  Widget _buildTeamsBar(List<Map<String, dynamic>> teams) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'КОМАНДЫ',
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              InkWell(
                onTap: _openCreateTeamDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 14, color: Color(0xFFFFB800)),
                      SizedBox(width: 4),
                      Text(
                        'Создать команду',
                        style: TextStyle(color: Color(0xFFFFB800), fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: teams.map((t) {
                final isSelected = t['id'].toString() == _activeTeamId;
                final name = t['name'] ?? 'Команда';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFFB800),
                    backgroundColor: const Color(0xFF141724),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFFFFB800) : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _activeTeamId = t['id'].toString();
                          _activeTeamName = name;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Список игроков внутри выбранной команды
  Widget _buildPlayersListForTeam(String teamId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('roster_${teamId}_$_refreshCounter'),
      future: Supabase.instance.client
          .from('player_profiles')
          .select('*, users(first_name, last_name)')
          .eq('team_id', teamId)
          .order('jersey_number', ascending: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)));
        }

        final players = snapshot.data ?? [];

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // Заголовок команды и кнопка добавления игрока
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF141724),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFFFFB800), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeTeamName ?? 'Команда',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Игроков в заявке: ${players.length}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB800),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openCreatePlayerDialog(teamId),
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Игрок', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (players.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF141724).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.person_outline, size: 40, color: Colors.white30),
                    const SizedBox(height: 10),
                    const Text(
                      'В этой команде пока нет игроков',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Нажмите «+ Игрок» выше, чтобы добавить первого футболиста',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(players.length, (index) {
                final p = players[index];
                final user = p['users'] as Map<String, dynamic>?;
                final fullName = '${user?['first_name'] ?? p['first_name'] ?? 'Игрок'} ${user?['last_name'] ?? p['last_name'] ?? ''}'.trim();
                final num = p['jersey_number'] ?? index + 1;
                final pos = p['position'] ?? 'ST';
                final ovr = p['ovr'] ?? 75;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _showPlayerDetailsDialog(p, fullName),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141724),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$num',
                              style: const TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                Text(
                                  'Позиция: $pos',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'OVR $ovr',
                              style: const TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // 1. Диалог создания команды
  void _openCreateTeamDialog() {
    final nameController = TextEditingController();
    final shortNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFFFFB800)),
            SizedBox(width: 8),
            Text('Новая команда', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Название команды *',
                labelStyle: const TextStyle(color: Colors.white60),
                hintText: 'например, Спартак Юниор',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: shortNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Краткое название (3-4 буквы)',
                labelStyle: const TextStyle(color: Colors.white60),
                hintText: 'СПР',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB800),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final short = shortNameController.text.trim();

              Navigator.of(ctx).pop();
              _createTeam(name: name, shortName: short.isEmpty ? name.substring(0, name.length >= 3 ? 3 : name.length).toUpperCase() : short);
            },
            child: const Text('Создать', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Future<void> _createTeam({required String name, required String shortName}) async {
    try {
      final res = await Supabase.instance.client.from('teams').insert({
        'name': name,
        'short_name': shortName,
      }).select().single();

      final newId = res['id'].toString();

      // Добавляем команду в таблицу турнира
      try {
        await Supabase.instance.client.from('tournament_standings').insert({
          'tournament_id': widget.tournamentId,
          'team_id': newId,
          'matches_played': 0,
          'wins': 0,
          'draws': 0,
          'losses': 0,
          'goals_for': 0,
          'goals_against': 0,
          'goal_difference': 0,
          'points': 0,
        });
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _activeTeamId = newId;
        _activeTeamName = name;
        _refreshCounter++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Команда «$name» успешно создана!'),
          backgroundColor: const Color(0xFF141724),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка создания команды: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // 2. Диалог добавления игрока в команду
  void _openCreatePlayerDialog(String teamId) {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final numberController = TextEditingController(text: '10');
    final ovrController = TextEditingController(text: '75');
    String selectedPos = 'ST';
    final positions = ['GK', 'CB', 'LB', 'RB', 'CM', 'CDM', 'CAM', 'LW', 'RW', 'ST'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141724),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Row(
            children: [
              const Icon(Icons.person_add, color: Color(0xFFFFB800)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Игрок: ${_activeTeamName ?? ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Имя *',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: lastNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Фамилия *',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: numberController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Номер (#)',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: ovrController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'OVR (Рейтинг)',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedPos,
                  dropdownColor: const Color(0xFF141724),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Позиция',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: positions.map((pos) => DropdownMenuItem(value: pos, child: Text(pos))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedPos = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB800),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final fName = firstNameController.text.trim();
                final lName = lastNameController.text.trim();
                if (fName.isEmpty && lName.isEmpty) return;

                final num = int.tryParse(numberController.text.trim()) ?? 10;
                final ovr = int.tryParse(ovrController.text.trim()) ?? 75;

                Navigator.of(ctx).pop();
                _createPlayer(
                  teamId: teamId,
                  firstName: fName,
                  lastName: lName,
                  number: num,
                  position: selectedPos,
                  ovr: ovr,
                );
              },
              child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPlayer({
    required String teamId,
    required String firstName,
    required String lastName,
    required int number,
    required String position,
    required int ovr,
  }) async {
    try {
      // 1. Пытаемся создать запись в users, если таблица связана
      String? newUserId;
      try {
        final uRes = await Supabase.instance.client.from('users').insert({
          'first_name': firstName,
          'last_name': lastName,
          'role': 'player',
        }).select().single();
        newUserId = uRes['id']?.toString();
      } catch (_) {}

      // 2. Создаем профиль игрока в player_profiles
      final Map<String, dynamic> insertData = {
        'team_id': teamId,
        'jersey_number': number,
        'position': position,
        'ovr': ovr,
      };
      if (newUserId != null) {
        insertData['user_id'] = newUserId;
      } else {
        insertData['first_name'] = firstName;
        insertData['last_name'] = lastName;
      }

      await Supabase.instance.client.from('player_profiles').insert(insertData);

      if (!mounted) return;
      setState(() => _refreshCounter++);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Игрок $firstName $lastName добавлен в команду!'),
          backgroundColor: const Color(0xFF141724),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка добавления игрока: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // 3. Карточка детальной информации об игроке
  void _showPlayerDetailsDialog(Map<String, dynamic> player, String fullName) {
    final num = player['jersey_number'] ?? 10;
    final pos = player['position'] ?? 'ST';
    final ovr = player['ovr'] ?? 75;
    final foot = player['preferred_foot'] ?? 'Правая';
    final teamName = _activeTeamName ?? 'Академия';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121420),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFFFB800), width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Верхняя часть карточки (Золотой герб и рейтинг)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$ovr',
                      style: const TextStyle(
                        color: Color(0xFFFFB800),
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      pos,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Text(
                    '#$num',
                    style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Имя и Команда
            Text(
              fullName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              teamName,
              style: const TextStyle(color: Color(0xFFFFB800), fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
            // Сетка ключевых футбольных атрибутов
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge('PAC', '${ovr + 2}'),
                _buildStatBadge('SHO', '${ovr - 3}'),
                _buildStatBadge('PAS', '${ovr - 1}'),
                _buildStatBadge('DRI', '${ovr + 1}'),
                _buildStatBadge('DEF', '${ovr - 10}'),
                _buildStatBadge('PHY', '${ovr - 4}'),
              ],
            ),
            const SizedBox(height: 16),
            // Дополнительная информация
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailRow('Нога', foot),
                  _buildDetailRow('Форма', '9.4 ★'),
                  _buildDetailRow('Статус', 'Основной'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Закрыть карточку', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}