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
  // 0: Таблица, 1: Календарь, 2: Тактика, 3: Состав & Команды
  int _selectedTab = 0;
  int _refreshCounter = 0;
  String _sportType = 'futsal'; // 'football' (7x7) или 'futsal' (5x5)
  String? _activeTeamId;
  String? _activeTeamName;

  // Тактические схемы
  String _selectedFootballFormation = '2-3-1';
  String _selectedFutsalFormation = '1-2-1 (Ромб)';
  String _selectedRoleFilter = 'ALL';

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
            const SizedBox(height: 10),
            _buildSportSelector(),
            const SizedBox(height: 10),
            _buildTabSelector(),
            const SizedBox(height: 10),
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

  // Переключатель вида спорта (Футбол 7х7 vs Зал 5х5)
  Widget _buildSportSelector() {
    final isFutsal = _sportType == 'futsal';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _sportType = 'football'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: !isFutsal ? const Color(0xFF2E7D32) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_soccer, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Футбол 7х7 (Газон)',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _sportType = 'futsal'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isFutsal ? const Color(0xFFD84315) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stadium, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Мини-футбол 5х5 (Зал)',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    final tabs = [
      {'title': 'Таблица', 'icon': Icons.emoji_events_outlined, 'selectedIcon': Icons.emoji_events},
      {'title': 'Календарь', 'icon': Icons.calendar_month_outlined, 'selectedIcon': Icons.calendar_month},
      {'title': 'Тактика', 'icon': Icons.dashboard_outlined, 'selectedIcon': Icons.dashboard},
      {'title': 'Состав', 'icon': Icons.groups_outlined, 'selectedIcon': Icons.groups},
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
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFB800) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFB800).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? (tab['selectedIcon'] as IconData) : (tab['icon'] as IconData),
                      size: 15,
                      color: isSelected ? Colors.black : Colors.white60,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tab['title'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
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
        return _buildTacticsTab();
      case 3:
        return _buildRosterAndTeamsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // 1. ТАБЛИЦА
  Widget _buildStandingsTab() {
    final title = _sportType == 'futsal'
        ? 'Первенство по мини-футболу (Зал U-10)'
        : 'Первенство U-10 • Золотая Лига';

    return SingleChildScrollView(
      key: ValueKey('tab_standings_${_refreshCounter}_$_sportType'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TournamentStandingsWidget(
            key: ValueKey('widget_standings_${_refreshCounter}_$_sportType'),
            tournamentId: widget.tournamentId,
            title: title,
            highlightTeamId: widget.myTeamId,
          ),
          const SizedBox(height: 16),
          if (widget.dynamicBlocks.isNotEmpty)
            DynamicBlockRenderer(blocks: widget.dynamicBlocks),
        ],
      ),
    );
  }

  // 2. КАЛЕНДАРЬ
  Widget _buildCalendarTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('tab_calendar_${_refreshCounter}_$_sportType'),
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
            child: Text('Расписание матчей формируется', style: TextStyle(color: Colors.white54, fontSize: 14)),
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
            final homeFouls = m['home_fouls'] ?? 0;
            final awayFouls = m['away_fouls'] ?? 0;

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
                          Icon(
                            _sportType == 'futsal' ? Icons.sports_volleyball : Icons.stadium_outlined,
                            size: 14,
                            color: Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            m['venue'] ?? (_sportType == 'futsal' ? 'Манеж / СК Олимп' : 'Основной стадион'),
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isFinished ? Colors.white10 : const Color(0xFFFFB800).withValues(alpha: 0.2),
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
                              child: const Icon(Icons.edit_note, color: Color(0xFFFFB800), size: 18),
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
                              color: isFinished ? const Color(0xFFFFB800).withValues(alpha: 0.4) : Colors.white12,
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
                  if (_sportType == 'futsal') ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Фолы: $homeFouls', style: TextStyle(color: homeFouls >= 5 ? Colors.redAccent : Colors.white38, fontSize: 11)),
                        const SizedBox(width: 14),
                        Text('Фолы: $awayFouls', style: TextStyle(color: awayFouls >= 5 ? Colors.redAccent : Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 3. ТАКТИЧЕСКАЯ ДОСКА (PITCH VIEW)
  Widget _buildTacticsTab() {
    final isFutsal = _sportType == 'futsal';
    final formations = isFutsal ? ['1-2-1 (Ромб)', '2-2 (Квадрат)', '4-0 (В линию)'] : ['2-3-1', '3-2-1', '2-2-2'];
    final currentFormation = isFutsal ? _selectedFutsalFormation : _selectedFootballFormation;

    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('tactics_roster_${_activeTeamId}_$_refreshCounter'),
      future: Supabase.instance.client
          .from('player_profiles')
          .select('*, users(first_name, last_name)')
          .eq('team_id', _activeTeamId ?? widget.myTeamId)
          .order('jersey_number', ascending: true),
      builder: (context, snapshot) {
        final players = snapshot.data ?? [];

        return Column(
          children: [
            // Панель выбора схемы
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('СХЕМА:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: formations.map((form) {
                          final isSel = form == currentFormation;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(form),
                              selected: isSel,
                              selectedColor: isFutsal ? const Color(0xFFD84315) : const Color(0xFF2E7D32),
                              backgroundColor: const Color(0xFF141724),
                              labelStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                                fontSize: 11,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: isSel ? Colors.white30 : Colors.white10),
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    if (isFutsal) {
                                      _selectedFutsalFormation = form;
                                    } else {
                                      _selectedFootballFormation = form;
                                    }
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Интерактивное тактическое поле
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          // Отрисовка поля (Газон или Паркет)
                          CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: isFutsal ? FutsalPitchPainter() : FootballPitchPainter(),
                          ),
                          // Размещение игроков по координатам схемы
                          ..._buildPitchPlayerNodes(
                            constraints: constraints,
                            isFutsal: isFutsal,
                            formation: currentFormation,
                            players: players,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Расчет координат игроков на поле
  List<Widget> _buildPitchPlayerNodes({
    required BoxConstraints constraints,
    required bool isFutsal,
    required String formation,
    required List<Map<String, dynamic>> players,
  }) {
    List<Map<String, dynamic>> slots = [];

    if (isFutsal) {
      if (formation == '1-2-1 (Ромб)') {
        slots = [
          {'pos': Offset(0.50, 0.90), 'role': 'ВРТ'},
          {'pos': Offset(0.50, 0.68), 'role': 'ФИКС'},
          {'pos': Offset(0.20, 0.46), 'role': 'Л.АЛА'},
          {'pos': Offset(0.80, 0.46), 'role': 'П.АЛА'},
          {'pos': Offset(0.50, 0.18), 'role': 'СТОЛБ'},
        ];
      } else if (formation == '2-2 (Квадрат)') {
        slots = [
          {'pos': Offset(0.50, 0.90), 'role': 'ВРТ'},
          {'pos': Offset(0.28, 0.65), 'role': 'Л.ЗАЩ'},
          {'pos': Offset(0.72, 0.65), 'role': 'П.ЗАЩ'},
          {'pos': Offset(0.28, 0.28), 'role': 'Л.НАП'},
          {'pos': Offset(0.72, 0.28), 'role': 'П.НАП'},
        ];
      } else {
        slots = [
          {'pos': Offset(0.50, 0.90), 'role': 'ВРТ'},
          {'pos': Offset(0.16, 0.52), 'role': 'АЛА'},
          {'pos': Offset(0.38, 0.58), 'role': 'ФИКС'},
          {'pos': Offset(0.62, 0.58), 'role': 'ФИКС'},
          {'pos': Offset(0.84, 0.52), 'role': 'АЛА'},
        ];
      }
    } else {
      if (formation == '2-3-1') {
        slots = [
          {'pos': Offset(0.50, 0.92), 'role': 'GK'},
          {'pos': Offset(0.28, 0.73), 'role': 'LB'},
          {'pos': Offset(0.72, 0.73), 'role': 'RB'},
          {'pos': Offset(0.18, 0.48), 'role': 'LM'},
          {'pos': Offset(0.50, 0.48), 'role': 'CM'},
          {'pos': Offset(0.82, 0.48), 'role': 'RM'},
          {'pos': Offset(0.50, 0.20), 'role': 'ST'},
        ];
      } else if (formation == '3-2-1') {
        slots = [
          {'pos': Offset(0.50, 0.92), 'role': 'GK'},
          {'pos': Offset(0.20, 0.73), 'role': 'LB'},
          {'pos': Offset(0.50, 0.75), 'role': 'CB'},
          {'pos': Offset(0.80, 0.73), 'role': 'RB'},
          {'pos': Offset(0.35, 0.48), 'role': 'CM'},
          {'pos': Offset(0.65, 0.48), 'role': 'CM'},
          {'pos': Offset(0.50, 0.20), 'role': 'ST'},
        ];
      } else {
        slots = [
          {'pos': Offset(0.50, 0.92), 'role': 'GK'},
          {'pos': Offset(0.30, 0.72), 'role': 'LB'},
          {'pos': Offset(0.70, 0.72), 'role': 'RB'},
          {'pos': Offset(0.30, 0.48), 'role': 'LM'},
          {'pos': Offset(0.70, 0.48), 'role': 'RM'},
          {'pos': Offset(0.30, 0.22), 'role': 'ST'},
          {'pos': Offset(0.70, 0.22), 'role': 'ST'},
        ];
      }
    }

    final double nodeSize = 46.0;
    return List.generate(slots.length, (i) {
      final slot = slots[i];
      final Offset offset = slot['pos'] as Offset;
      final String role = slot['role'] as String;
      final player = i < players.length ? players[i] : null;
      final user = player?['users'] as Map<String, dynamic>?;
      final name = player != null
          ? '${user?['last_name'] ?? player['last_name'] ?? 'Игрок'}'
          : role;
      final number = player?['jersey_number'] ?? (i + 1);

      final double x = offset.dx * constraints.maxWidth - (nodeSize / 2);
      final double y = offset.dy * constraints.maxHeight - (nodeSize / 2);

      return Positioned(
        left: x,
        top: y,
        child: GestureDetector(
          onTap: () {
            if (player != null) {
              final fullName = '${user?['first_name'] ?? player['first_name'] ?? ''} ${user?['last_name'] ?? player['last_name'] ?? ''}'.trim();
              _showPlayerDetailsDialog(player, fullName);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: nodeSize,
                height: nodeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFutsal ? const Color(0xFFD84315) : const Color(0xFF1E88E5),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$number',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  name,
                  maxLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // 4. СОСТАВ И КОМАНДЫ
  Widget _buildRosterAndTeamsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('teams_list_${_refreshCounter}_$_sportType'),
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
            _buildTeamsBar(teams),
            const SizedBox(height: 6),
            Expanded(
              child: _activeTeamId == null
                  ? const Center(child: Text('Создайте первую команду', style: TextStyle(color: Colors.white54)))
                  : _buildPlayersListForTeam(_activeTeamId!),
            ),
          ],
        );
      },
    );
  }

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
                      Text('Создать команду', style: TextStyle(color: Color(0xFFFFB800), fontSize: 11, fontWeight: FontWeight.w800)),
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

  bool _matchesRole(String position, String filter) {
    if (filter == 'ALL') return true;
    final pos = position.toUpperCase();
    if (_sportType == 'futsal') {
      if (filter == 'GK') return pos.contains('ВРТ') || pos == 'GK';
      if (filter == 'DEF') return pos.contains('ФИКС') || pos.contains('ЗАЩ');
      if (filter == 'MID') return pos.contains('АЛА');
      if (filter == 'ATT') return pos.contains('СТОЛБ') || pos.contains('НАП');
      return true;
    }
    if (filter == 'GK') return pos == 'GK';
    if (filter == 'DEF') return ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(pos);
    if (filter == 'MID') return ['CM', 'CDM', 'CAM', 'LM', 'RM'].contains(pos);
    if (filter == 'ATT') return ['ST', 'CF', 'LW', 'RW'].contains(pos);
    return true;
  }

  Widget _buildRoleFilterChips() {
    final filters = [
      {'key': 'ALL', 'label': 'Все'},
      {'key': 'GK', 'label': _sportType == 'futsal' ? 'Вратари' : 'Вратари (GK)'},
      {'key': 'DEF', 'label': _sportType == 'futsal' ? 'Фиксо' : 'Защита'},
      {'key': 'MID', 'label': _sportType == 'futsal' ? 'Ала' : 'Полузащита'},
      {'key': 'ATT', 'label': _sportType == 'futsal' ? 'Столбы' : 'Атака'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedRoleFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() => _selectedRoleFilter = f['key']!),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.12) : const Color(0xFF141724),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFFB800) : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFFFB800) : Colors.white60,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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

        final allPlayers = snapshot.data ?? [];
        final filteredPlayers = allPlayers.where((p) {
          final pos = p['position']?.toString() ?? 'ST';
          return _matchesRole(pos, _selectedRoleFilter);
        }).toList();

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
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
                          'Игроков в заявке: ${allPlayers.length}',
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
            const SizedBox(height: 10),
            _buildRoleFilterChips(),
            const SizedBox(height: 12),

            if (allPlayers.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF141724).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.person_outline, size: 40, color: Colors.white30),
                    SizedBox(height: 10),
                    Text('В этой команде пока нет игроков', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('Нажмите «+ Игрок» выше, чтобы добавить первого футболиста', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              )
            else if (filteredPlayers.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Text('Нет игроков с выбранным амплуа', style: TextStyle(color: Colors.white38, fontSize: 13)),
              )
            else
              ...List.generate(filteredPlayers.length, (index) {
                final p = filteredPlayers[index];
                final user = p['users'] as Map<String, dynamic>?;
                final fullName = '${user?['first_name'] ?? p['first_name'] ?? 'Игрок'} ${user?['last_name'] ?? p['last_name'] ?? ''}'.trim();
                final num = p['jersey_number'] ?? index + 1;
                final pos = p['position'] ?? (_sportType == 'futsal' ? 'АЛА' : 'ST');
                final ovr = p['ovr'] ?? 75;
                final avatarUrl = p['avatar_url']?.toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _showPlayerDetailsDialog(p, fullName),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141724),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          _buildPlayerAvatar(avatarUrl: avatarUrl, number: num, size: 38),
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

  Widget _buildPlayerAvatar({String? avatarUrl, required int number, double size = 36}) {
    if (avatarUrl != null && avatarUrl.trim().startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 3),
        child: Image.network(
          avatarUrl.trim(),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(number, size),
        ),
      );
    }
    return _buildFallbackAvatar(number, size);
  }

  Widget _buildFallbackAvatar(int number, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(size / 3),
        border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
      ),
      child: Text(
        '#$number',
        style: TextStyle(color: const Color(0xFFFFB800), fontWeight: FontWeight.bold, fontSize: size * 0.36),
      ),
    );
  }

  // ДИАЛОГИ И МЕТОДЫ УПРАВЛЕНИЯ
  void _openScoreEditDialog(Map<String, dynamic> match, String homeTeam, String awayTeam) {
    final homeController = TextEditingController(text: match['home_score']?.toString() ?? '0');
    final awayController = TextEditingController(text: match['away_score']?.toString() ?? '0');
    final homeFoulsController = TextEditingController(text: match['home_fouls']?.toString() ?? '0');
    final awayFoulsController = TextEditingController(text: match['away_fouls']?.toString() ?? '0');
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
              Text('Результат матча', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(homeTeam, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
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
                          Text(awayTeam, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
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
                if (_sportType == 'futsal') ...[
                  const SizedBox(height: 14),
                  const Text('Командные фолы (Футзал):', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: homeFoulsController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Фолы $homeTeam',
                            labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: awayFoulsController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Фолы $awayTeam',
                            labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFFFFB800),
                  title: const Text('Матч завершен', style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: isFinished,
                  onChanged: (val) => setDialogState(() => isFinished = val),
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
                final hScore = int.tryParse(homeController.text.trim()) ?? 0;
                final aScore = int.tryParse(awayController.text.trim()) ?? 0;
                final hFouls = int.tryParse(homeFoulsController.text.trim()) ?? 0;
                final aFouls = int.tryParse(awayFoulsController.text.trim()) ?? 0;
                final newStatus = isFinished ? 'finished' : 'scheduled';
                final matchId = match['id'].toString();

                Navigator.of(ctx).pop();
                _updateMatchScore(
                  matchId: matchId,
                  homeScore: hScore,
                  awayScore: aScore,
                  homeFouls: hFouls,
                  awayFouls: aFouls,
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
    required int homeFouls,
    required int awayFouls,
    required String status,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'home_score': homeScore,
        'away_score': awayScore,
        'status': status,
      };
      if (_sportType == 'futsal') {
        updateData['home_fouls'] = homeFouls;
        updateData['away_fouls'] = awayFouls;
      }

      await Supabase.instance.client.from('matches').update(updateData).eq('id', matchId);

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
        SnackBar(content: Text('Ошибка обновления: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

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

  void _openCreatePlayerDialog(String teamId) {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final numberController = TextEditingController(text: '10');
    final ovrController = TextEditingController(text: '75');
    final avatarController = TextEditingController();

    final isFutsal = _sportType == 'futsal';
    final positions = isFutsal
        ? ['ВРТ', 'ФИКС', 'АЛА', 'СТОЛБ', '5-Й']
        : ['GK', 'CB', 'LB', 'RB', 'CM', 'CDM', 'CAM', 'LW', 'RW', 'ST'];
    String selectedPos = positions.first;
    String selectedFoot = 'Правая';

    final presetAvatars = [
      'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150',
      'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150',
    ];

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
                child: Text('Новый игрок: ${_activeTeamName ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedPos,
                        dropdownColor: const Color(0xFF141724),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Амплуа',
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
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedFoot,
                        dropdownColor: const Color(0xFF141724),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Нога',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Правая', child: Text('Правая')),
                          DropdownMenuItem(value: 'Левая', child: Text('Левая')),
                          DropdownMenuItem(value: 'Обе', child: Text('Обе')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedFoot = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: avatarController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'URL аватара',
                    labelStyle: const TextStyle(color: Colors.white60),
                    hintText: 'https://...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Пресеты: ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ...presetAvatars.map((url) => GestureDetector(
                      onTap: () => setDialogState(() => avatarController.text = url),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFFB800), width: 1),
                        ),
                        child: CircleAvatar(radius: 12, backgroundImage: NetworkImage(url)),
                      ),
                    )),
                  ],
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
                final avatar = avatarController.text.trim();

                Navigator.of(ctx).pop();
                _createPlayer(
                  teamId: teamId,
                  firstName: fName,
                  lastName: lName,
                  number: num,
                  position: selectedPos,
                  ovr: ovr,
                  preferredFoot: selectedFoot,
                  avatarUrl: avatar,
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
    required String preferredFoot,
    required String avatarUrl,
  }) async {
    try {
      String? newUserId;
      try {
        final uRes = await Supabase.instance.client.from('users').insert({
          'first_name': firstName,
          'last_name': lastName,
          'role': 'player',
        }).select().single();
        newUserId = uRes['id']?.toString();
      } catch (_) {}

      final Map<String, dynamic> insertData = {
        'team_id': teamId,
        'jersey_number': number,
        'position': position,
        'ovr': ovr,
        'preferred_foot': preferredFoot,
        'first_name': firstName,
        'last_name': lastName,
      };
      if (newUserId != null) insertData['user_id'] = newUserId;
      if (avatarUrl.isNotEmpty) insertData['avatar_url'] = avatarUrl;

      await Supabase.instance.client.from('player_profiles').insert(insertData);

      if (!mounted) return;
      setState(() => _refreshCounter++);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Игрок $firstName $lastName добавлен!'),
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

  void _showPlayerDetailsDialog(Map<String, dynamic> player, String fullName) {
    final num = player['jersey_number'] ?? 10;
    final pos = player['position'] ?? 'ST';
    final ovr = player['ovr'] ?? 75;
    final foot = player['preferred_foot'] ?? 'Правая';
    final teamName = _activeTeamName ?? 'Академия';
    final avatarUrl = player['avatar_url']?.toString();

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$ovr',
                      style: const TextStyle(color: Color(0xFFFFB800), fontSize: 34, fontWeight: FontWeight.w900, height: 1.0),
                    ),
                    Text(
                      pos,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ],
                ),
                _buildPlayerAvatar(avatarUrl: avatarUrl, number: num, size: 64),
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Text('#$num', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              fullName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(teamName, style: const TextStyle(color: Color(0xFFFFB800), fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
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
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailRow('Нога', foot),
                  _buildDetailRow('Дисциплина', _sportType == 'futsal' ? 'Футзал' : 'Футбол'),
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
              child: const Text('Закрыть', style: TextStyle(color: Colors.white54)),
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

// ---------------------------------------------------------------------------
// ОТРИСОВКА ФУТБОЛЬНОГО ПОЛЯ (ГАЗОН С ПОЛОСАМИ)
// ---------------------------------------------------------------------------
class FootballPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF1E4620);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final stripePaint = Paint()..color = const Color(0xFF235326);
    final int stripes = 8;
    final double stripeH = size.height / stripes;
    for (int i = 0; i < stripes; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * stripeH, size.width, stripeH), stripePaint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final pad = 12.0;
    final pitchRect = Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    canvas.drawRect(pitchRect, linePaint);

    canvas.drawLine(
      Offset(pad, size.height / 2),
      Offset(size.width - pad, size.height / 2),
      linePaint,
    );

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.16, linePaint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 3.0, Paint()..color = Colors.white.withValues(alpha: 0.7));

    final boxW = size.width * 0.55;
    final boxH = size.height * 0.16;
    canvas.drawRect(Rect.fromLTWH((size.width - boxW) / 2, pad, boxW, boxH), linePaint);
    canvas.drawRect(Rect.fromLTWH((size.width - boxW) / 2, size.height - pad - boxH, boxW, boxH), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// ОТРИСОВКА МИНИ-ФУТБОЛЬНОГО ПОЛЯ (ПАРКЕТ / ТЕРАФЛЕКС В ЗАЛЕ)
// ---------------------------------------------------------------------------
class FutsalPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final woodPaint = Paint()..color = const Color(0xFF8D4018);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), woodPaint);

    final plankPaint = Paint()
      ..color = const Color(0xFF7B3512)
      ..strokeWidth = 1.0;
    final int planks = 24;
    final double plankW = size.width / planks;
    for (int i = 1; i < planks; i++) {
      canvas.drawLine(Offset(i * plankW, 0), Offset(i * plankW, size.height), plankPaint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final pad = 12.0;
    final courtRect = Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    canvas.drawRect(courtRect, linePaint);

    canvas.drawLine(
      Offset(pad, size.height / 2),
      Offset(size.width - pad, size.height / 2),
      linePaint,
    );

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.18, linePaint);

    // 6-метровые вратарские дуги
    final arcR = size.width * 0.32;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width / 2, pad), radius: arcR),
      0,
      3.14159,
      false,
      linePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width / 2, size.height - pad), radius: arcR),
      3.14159,
      3.14159,
      false,
      linePaint,
    );

    // Отметки 10-метрового дабл-пенальти
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.28), 3.0, dotPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.72), 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}