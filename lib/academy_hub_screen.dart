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
  int _selectedTab = 0; // 0: Таблица, 1: Календарь, 2: Состав

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0C0D12),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Внутренний сегментный переключатель вкладок
            _buildTabSelector(),
            const SizedBox(height: 12),
            // Контент выбранной вкладки
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
        return _buildRosterTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // Вкладка 1: Турнирная таблица + Динамические блоки
  Widget _buildStandingsTab() {
    return SingleChildScrollView(
      key: const ValueKey('tab_standings'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TournamentStandingsWidget(
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

  // Вкладка 2: Календарь матчей
  Widget _buildCalendarTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: const ValueKey('tab_calendar'),
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
                      Text(
                        m['venue'] ?? 'Основной стадион',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
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
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          scoreText,
                          style: TextStyle(
                            color: isFinished ? const Color(0xFFFFB800) : Colors.white70,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
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

  // Вкладка 3: Состав команды
  Widget _buildRosterTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: const ValueKey('tab_roster'),
      future: Supabase.instance.client
          .from('player_profiles')
          .select('*, users(first_name, last_name)')
          .order('jersey_number', ascending: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)));
        }

        final players = snapshot.data ?? [];
        if (players.isEmpty) {
          return const Center(
            child: Text('Состав команды пуст', style: TextStyle(color: Colors.white54, fontSize: 14)),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: players.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final p = players[index];
            final user = p['users'] as Map<String, dynamic>?;
            final fullName = '${user?['first_name'] ?? 'Игрок'} ${user?['last_name'] ?? ''}'.trim();
            final num = p['jersey_number'] ?? index + 1;
            final pos = p['position'] ?? 'ST';
            final ovr = p['ovr'] ?? 70;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF141724),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'OVR $ovr',
                      style: const TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}