import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tournament_standings_widget.dart';
import 'widgets/dynamic_block_renderer.dart';

class CapitalizeWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final words = text.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1) : '');
    }).join(' ');

    return TextEditingValue(
      text: capitalizedWords,
      selection: newValue.selection,
    );
  }
}

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

class _AcademyHubScreenState extends State<AcademyHubScreen> with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  int _refreshCounter = 0;
  bool _isFullscreenTactics = false;

  String _sportType = 'futsal'; 
  String? _activeTeamId;
  String? _activeTeamName;

  String _selectedFutsalFormation = '1-2-1 (Ромб)';
  String _selectedFootballFormation = '2-3-1';

  final List<String> _futsalFormations = [
    '1-2-1 (Ромб)',
    '2-2 (Квадрат)',
    '3-1 (Со столбом)',
    '4-0 (В линию)',
    '5-0 (5-й полевой)',
  ];

  final List<String> _footballFormations = [
    '2-3-1',
    '3-2-1',
    '2-2-2',
  ];

  List<Offset> _pitchPositions = [];
  List<String> _onPitchPlayerIds = [];

  final Map<int, List<Offset>> _playerTrails = {};
  Offset _ballPosition = const Offset(0.50, 0.50);
  List<Offset> _ballTrail = [];

  // Индекс активного игрока, которого удерживают пальцем
  int? _activeTouchPlayerIndex;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  Future<List<Map<String, dynamic>>>? _tacticsFuture;
  Future<List<Map<String, dynamic>>>? _calendarFuture;
  Future<List<Map<String, dynamic>>>? _teamsFuture;
  Future<List<Map<String, dynamic>>>? _scorersFuture;

  @override
  void initState() {
    super.initState();
    _activeTeamId = widget.myTeamId;

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _blinkAnimation = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _resetFormationPositions();
    _loadAllFutures();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  void _loadAllFutures() {
    _loadTacticsFuture();
    _calendarFuture = Supabase.instance.client
        .from('matches')
        .select()
        .order('match_date', ascending: false);
    _teamsFuture = Supabase.instance.client
        .from('teams')
        .select()
        .order('name');
    _scorersFuture = Supabase.instance.client
        .from('match_events')
        .select();
  }

  void _loadTacticsFuture() {
    _tacticsFuture = Supabase.instance.client
        .from('player_profiles')
        .select()
        .eq('team_id', _activeTeamId ?? widget.myTeamId)
        .order('jersey_number', ascending: true);
  }

  void _resetFormationPositions() {
    final isFutsal = _sportType == 'futsal';
    final form = isFutsal ? _selectedFutsalFormation : _selectedFootballFormation;
    setState(() {
      _pitchPositions = _getDefaultPositions(isFutsal, form);
      _playerTrails.clear();
      _ballPosition = const Offset(0.50, 0.50);
      _ballTrail.clear();
      _activeTouchPlayerIndex = null;
    });
    _blinkController.stop();
  }

  void _resetBallToCenter() {
    setState(() {
      _ballPosition = const Offset(0.50, 0.50);
      _ballTrail.clear();
    });
  }

  void _clearTrails() {
    setState(() {
      _playerTrails.clear();
      _ballTrail.clear();
    });
  }

  String _capitalizeWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1) : '');
    }).join(' ');
  }

  List<Offset> _getDefaultPositions(bool isFutsal, String formation) {
    if (isFutsal) {
      switch (formation) {
        case '2-2 (Квадрат)':
          return [
            const Offset(0.50, 0.88),
            const Offset(0.28, 0.65),
            const Offset(0.72, 0.65),
            const Offset(0.28, 0.32),
            const Offset(0.72, 0.32),
          ];
        case '3-1 (Со столбом)':
          return [
            const Offset(0.50, 0.88),
            const Offset(0.20, 0.64),
            const Offset(0.50, 0.72),
            const Offset(0.80, 0.64),
            const Offset(0.50, 0.22),
          ];
        case '4-0 (В линию)':
          return [
            const Offset(0.50, 0.88),
            const Offset(0.16, 0.50),
            const Offset(0.38, 0.58),
            const Offset(0.62, 0.58),
            const Offset(0.84, 0.50),
          ];
        case '5-0 (5-й полевой)':
          return [
            const Offset(0.50, 0.62),
            const Offset(0.18, 0.38),
            const Offset(0.82, 0.38),
            const Offset(0.32, 0.20),
            const Offset(0.68, 0.20),
          ];
        case '1-2-1 (Ромб)':
        default:
          return [
            const Offset(0.50, 0.88),
            const Offset(0.50, 0.68),
            const Offset(0.20, 0.46),
            const Offset(0.80, 0.46),
            const Offset(0.50, 0.22),
          ];
      }
    } else {
      switch (formation) {
        case '3-2-1':
          return [
            const Offset(0.50, 0.90),
            const Offset(0.22, 0.72),
            const Offset(0.50, 0.74),
            const Offset(0.78, 0.72),
            const Offset(0.32, 0.46),
            const Offset(0.68, 0.46),
            const Offset(0.50, 0.22),
          ];
        case '2-2-2':
          return [
            const Offset(0.50, 0.90),
            const Offset(0.30, 0.72),
            const Offset(0.70, 0.72),
            const Offset(0.30, 0.48),
            const Offset(0.70, 0.48),
            const Offset(0.32, 0.22),
            const Offset(0.68, 0.22),
          ];
        case '2-3-1':
        default:
          return [
            const Offset(0.50, 0.90),
            const Offset(0.28, 0.72),
            const Offset(0.72, 0.72),
            const Offset(0.18, 0.48),
            const Offset(0.50, 0.48),
            const Offset(0.82, 0.48),
            const Offset(0.50, 0.22),
          ];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreenTactics) {
      return KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() => _isFullscreenTactics = false);
          }
        },
        child: Container(
          color: const Color(0xFF0C0D12),
          child: SafeArea(
            child: _buildTacticsTab(isFullscreen: true),
          ),
        ),
      );
    }

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
              onTap: () {
                if (_sportType != 'futsal') {
                  setState(() {
                    _sportType = 'futsal';
                    _onPitchPlayerIds.clear();
                    _resetFormationPositions();
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isFutsal ? const Color(0xFF1E5E3A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stadium, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Мини-футбол 5х5 (Зал)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_sportType != 'football') {
                  setState(() {
                    _sportType = 'football';
                    _onPitchPlayerIds.clear();
                    _resetFormationPositions();
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !isFutsal ? const Color(0xFF2E7D32) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_soccer, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Футбол 7х7 (Газон)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
      {'title': 'Бомбардиры', 'icon': Icons.military_tech_outlined, 'selectedIcon': Icons.military_tech},
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedTab == index;
            final tab = tabs[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFB800) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
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
        return _buildTopScorersTab();
      case 3:
        return _buildTacticsTab(isFullscreen: false);
      case 4:
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
      key: ValueKey('tab_calendar_$_refreshCounter'),
      future: _calendarFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Ошибка календаря: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          );
        }

        final matches = snapshot.data ?? [];

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'КАЛЕНДАРЬ МАТЧЕЙ (${matches.length})',
                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB800),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _openScheduleMatchDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Назначить матч', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (matches.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF141724),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Матчей пока нет. Нажмите «Назначить матч» выше.', style: TextStyle(color: Colors.white54, fontSize: 13)),
              )
            else
              ...List.generate(matches.length, (index) {
                final m = matches[index];
                final isFinished = m['status'] == 'finished';
                final scoreText = isFinished ? '${m['home_score']} : ${m['away_score']}' : 'VS';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141724),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        m['venue'] ?? 'Стадион',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        scoreText,
                        style: const TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        onPressed: () async {
                          await Supabase.instance.client.from('matches').delete().eq('id', m['id']);
                          setState(() {
                            _refreshCounter++;
                            _calendarFuture = Supabase.instance.client
                                .from('matches')
                                .select()
                                .order('match_date', ascending: false);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  void _openScheduleMatchDialog() async {
    final teamsRes = await Supabase.instance.client.from('teams').select('id, name').order('name');
    final teams = List<Map<String, dynamic>>.from(teamsRes);

    if (!mounted) return;
    if (teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для создания матча нужно минимум 2 команды во вкладке Состав!'), backgroundColor: Colors.orange),
      );
      return;
    }

    String homeId = teams[0]['id'].toString();
    String awayId = teams[1]['id'].toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141724),
          title: const Text('Назначить матч', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: homeId,
                dropdownColor: const Color(0xFF141724),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Хозяева', labelStyle: TextStyle(color: Colors.white60)),
                items: teams.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['name']))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => homeId = val);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: awayId,
                dropdownColor: const Color(0xFF141724),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Гости', labelStyle: TextStyle(color: Colors.white60)),
                items: teams.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['name']))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => awayId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB800), foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Supabase.instance.client.from('matches').insert({
                  'home_team_id': homeId,
                  'away_team_id': awayId,
                  'match_date': DateTime.now().toIso8601String(),
                  'venue': _sportType == 'futsal' ? 'Манеж СК Олимп' : 'Основной стадион',
                  'status': 'scheduled',
                  'home_score': 0,
                  'away_score': 0,
                  'sport_type': _sportType,
                });
                setState(() {
                  _refreshCounter++;
                  _calendarFuture = Supabase.instance.client
                      .from('matches')
                      .select()
                      .order('match_date', ascending: false);
                });
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  // 3. БОМБАРДИРЫ
  Widget _buildTopScorersTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('scorers_$_refreshCounter'),
      future: _scorersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Ошибка бомбардиров: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          );
        }

        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return const Center(
            child: Text('Список бомбардиров пуст', style: TextStyle(color: Colors.white54, fontSize: 14)),
          );
        }

        return ListView.builder(
          itemCount: events.length,
          itemBuilder: (ctx, i) {
            final ev = events[i];
            return ListTile(
              leading: const Text('⚽', style: TextStyle(fontSize: 20)),
              title: Text('Событие матча #${ev['minute'] ?? 1} мин', style: const TextStyle(color: Colors.white)),
            );
          },
        );
      },
    );
  }

  // 4. ТАКТИКА (ИНТЕРАКТИВНОЕ ПОЛЕ С МИГАЮЩИМИ ФИШКАМИ И РАЗВОРОТОМ НА ВЕСЬ ЭКРАН)
  Widget _buildTacticsTab({required bool isFullscreen}) {
    final isFutsal = _sportType == 'futsal';
    final currentFormation = isFutsal ? _selectedFutsalFormation : _selectedFootballFormation;
    final formationsList = isFutsal ? _futsalFormations : _footballFormations;
    final int targetStartersCount = isFutsal ? 5 : 7;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _tacticsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _pitchPositions.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)));
        }

        final allPlayers = snapshot.data ?? [];

        if (_onPitchPlayerIds.isEmpty && allPlayers.isNotEmpty) {
          _onPitchPlayerIds = allPlayers.take(targetStartersCount).map((p) => p['id'].toString()).toList();
        }

        final starters = <Map<String, dynamic>>[];
        final bench = <Map<String, dynamic>>[];

        for (final p in allPlayers) {
          final pid = p['id'].toString();
          if (_onPitchPlayerIds.contains(pid)) {
            starters.add(p);
          } else {
            bench.add(p);
          }
        }

        while (starters.length < targetStartersCount && bench.isNotEmpty) {
          final extra = bench.removeAt(0);
          starters.add(extra);
          _onPitchPlayerIds.add(extra['id'].toString());
        }

        if (_pitchPositions.length != targetStartersCount) {
          _pitchPositions = _getDefaultPositions(isFutsal, currentFormation);
        }

        return Column(
          children: [
            // ПАНЕЛЬ ИНСТРУМЕНТОВ
            Container(
              margin: EdgeInsets.fromLTRB(isFullscreen ? 10 : 16, 4, isFullscreen ? 10 : 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF141724),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  if (isFullscreen) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB800),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => setState(() => _isFullscreenTactics = false),
                      icon: const Icon(Icons.fullscreen_exit, size: 20),
                      label: const Text('Свернуть', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                  ],

                  const Icon(Icons.alt_route, color: Color(0xFFFFB800), size: 16),
                  const SizedBox(width: 6),
                  const Text('Схема:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),

                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentFormation,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF181C2E),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFB800)),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        items: formationsList.map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              if (isFutsal) {
                                _selectedFutsalFormation = val;
                              } else {
                                _selectedFootballFormation = val;
                              }
                              _resetFormationPositions();
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Мяч в центр',
                    icon: const Icon(Icons.sports_soccer, color: Colors.white, size: 19),
                    onPressed: _resetBallToCenter,
                  ),

                  IconButton(
                    tooltip: 'Очистить стрелки и передачи',
                    icon: const Icon(Icons.gesture_outlined, color: Color(0xFFFFB800), size: 18),
                    onPressed: _clearTrails,
                  ),
                  IconButton(
                    tooltip: 'Сбросить схему',
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                    onPressed: _resetFormationPositions,
                  ),

                  if (!isFullscreen)
                    IconButton(
                      tooltip: 'Развернуть на весь экран',
                      icon: const Icon(Icons.fullscreen, color: Color(0xFFFFB800), size: 22),
                      onPressed: () => setState(() => _isFullscreenTactics = true),
                    ),
                ],
              ),
            ),

            // ИГРОВОЕ ПОЛЕ (ТАП ПО ПОЛЮ РАСКРЫВАЕТ НА ВЕСЬ ЭКРАН)
            Expanded(
              flex: isFullscreen ? 8 : 5,
              child: GestureDetector(
                onDoubleTap: () => setState(() => _isFullscreenTactics = !_isFullscreenTactics),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: isFullscreen ? 10 : 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // 1. Поле
                            CustomPaint(
                              size: Size(constraints.maxWidth, constraints.maxHeight),
                              painter: isFutsal ? FutsalPitchPainter() : FootballPitchPainter(),
                            ),

                            // 2. Сплайн-траектории (желтые и белые)
                            CustomPaint(
                              size: Size(constraints.maxWidth, constraints.maxHeight),
                              painter: TrajectoryPainter(
                                trails: _playerTrails,
                                ballTrail: _ballTrail,
                              ),
                            ),

                            // 3. Фишки игроков (уменьшенный радиус на 2 мм + мигание)
                            ..._buildDraggablePlayerNodes(
                              constraints: constraints,
                              isFutsal: isFutsal,
                              starters: starters,
                            ),

                            // 4. Мяч
                            _buildDraggableBallNode(constraints: constraints),

                            // 5. Кнопка сворачивания / разворачивания
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Material(
                                color: isFullscreen ? const Color(0xFFFFB800) : Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(() => _isFullscreenTactics = !_isFullscreenTactics),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Row(
                                      mainAxisSize: dynamicMinSize(),
                                      children: [
                                        Icon(
                                          isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                          color: isFullscreen ? Colors.black : const Color(0xFFFFB800),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isFullscreen ? 'Свернуть' : 'На весь экран',
                                          style: TextStyle(
                                            color: isFullscreen ? Colors.black : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // СКАМЕЙКА ЗАПАСНЫХ
            Expanded(
              flex: isFullscreen ? 2 : 2,
              child: Container(
                margin: EdgeInsets.fromLTRB(isFullscreen ? 10 : 16, 8, isFullscreen ? 10 : 16, 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF141724), borderRadius: BorderRadius.circular(14)),
                child: bench.isEmpty
                    ? const Center(child: Text('Все игроки на поле', style: TextStyle(color: Colors.white38, fontSize: 12)))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: bench.length,
                        itemBuilder: (ctx, i) {
                          final p = bench[i];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              backgroundColor: Colors.black45,
                              label: Text('${p['last_name'] ?? 'Игрок'} #${p['jersey_number'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // ФИШКА МЯЧА
  // -------------------------------------------------------------
  Widget _buildDraggableBallNode({required BoxConstraints constraints}) {
    const double ballSize = 34.0;
    final double x = (_ballPosition.dx * constraints.maxWidth - (ballSize / 2)).clamp(4.0, constraints.maxWidth - ballSize - 4.0);
    final double y = (_ballPosition.dy * constraints.maxHeight - (ballSize / 2)).clamp(4.0, constraints.maxHeight - ballSize - 4.0);

    return Positioned(
      left: x,
      top: y,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            setState(() {
              _ballTrail = [_ballPosition];
            });
          },
          onPanUpdate: (details) {
            setState(() {
              final double newDx = (_ballPosition.dx + details.delta.dx / constraints.maxWidth).clamp(0.04, 0.96);
              final double newDy = (_ballPosition.dy + details.delta.dy / constraints.maxHeight).clamp(0.04, 0.96);
              final newPos = Offset(newDx, newDy);
              _ballPosition = newPos;

              if (_ballTrail.isEmpty || (_ballTrail.last - newPos).distance > 0.01) {
                _ballTrail.add(newPos);
              }
            });
          },
          child: Container(
            width: ballSize,
            height: ballSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFFFB800), width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.sports_soccer,
                size: 21,
                color: Color(0xFF1E1E1E),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // ФИШКИ ИГРОКОВ (РАДИУС НА 2 ММ МЕНЬШЕ + МИГАНИЕ ПРИ КАСАНИИ)
  // -------------------------------------------------------------
  List<Widget> _buildDraggablePlayerNodes({
    required BoxConstraints constraints,
    required bool isFutsal,
    required List<Map<String, dynamic>> starters,
  }) {
    // Размер 36.0 (радиус 18.0 вместо 24.0 — ровно на 2 мм компактнее)
    const double nodeSize = 36.0;

    return List.generate(_pitchPositions.length, (i) {
      final pos = _pitchPositions[i];
      final player = i < starters.length ? starters[i] : null;
      final name = player != null ? '${player['last_name'] ?? 'Игрок'}' : 'Слот';
      final number = player?['jersey_number'] ?? (i + 1);

      final double x = (pos.dx * constraints.maxWidth - (nodeSize / 2)).clamp(4.0, constraints.maxWidth - nodeSize - 4.0);
      final double y = (pos.dy * constraints.maxHeight - (nodeSize / 2)).clamp(4.0, constraints.maxHeight - nodeSize - 4.0);

      final isTouching = _activeTouchPlayerIndex == i;

      return Positioned(
        left: x,
        top: y,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Касание пальцем: включаем мигание
            onPanDown: (_) {
              setState(() => _activeTouchPlayerIndex = i);
              _blinkController.repeat(reverse: true);
            },
            onPanStart: (details) {
              setState(() {
                _activeTouchPlayerIndex = i;
                _playerTrails[i] = [_pitchPositions[i]];
              });
              if (!_blinkController.isAnimating) {
                _blinkController.repeat(reverse: true);
              }
            },
            // Перемещение
            onPanUpdate: (details) {
              setState(() {
                final double newDx = (_pitchPositions[i].dx + details.delta.dx / constraints.maxWidth).clamp(0.04, 0.96);
                final double newDy = (_pitchPositions[i].dy + details.delta.dy / constraints.maxHeight).clamp(0.04, 0.96);
                final newPos = Offset(newDx, newDy);
                _pitchPositions[i] = newPos;

                final trail = _playerTrails[i] ?? [_pitchPositions[i]];
                if (trail.isEmpty || (trail.last - newPos).distance > 0.01) {
                  trail.add(newPos);
                  _playerTrails[i] = trail;
                }
              });
            },
            // Отпускание пальца: мигание гаснет
            onPanEnd: (_) {
              setState(() => _activeTouchPlayerIndex = null);
              _blinkController.stop();
            },
            onPanCancel: () {
              setState(() => _activeTouchPlayerIndex = null);
              _blinkController.stop();
            },
            child: AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (context, child) {
                final double blinkVal = isTouching ? _blinkAnimation.value : 0.0;
                final baseColor = isFutsal ? const Color(0xFF1565C0) : const Color(0xFF283593);
                final circleColor = isTouching
                    ? Color.lerp(baseColor, const Color(0xFFFFD54F), blinkVal)!
                    : baseColor;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: nodeSize,
                      height: nodeSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: circleColor,
                        border: Border.all(
                          color: isTouching ? Colors.white : Colors.white.withValues(alpha: 0.9),
                          width: isTouching ? 2.6 : 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isTouching
                                ? const Color(0xFFFFD54F).withValues(alpha: 0.5 + blinkVal * 0.45)
                                : Colors.black.withValues(alpha: 0.55),
                            blurRadius: isTouching ? (8.0 + blinkVal * 8.0) : 6.0,
                            spreadRadius: isTouching ? (1.5 + blinkVal * 2.0) : 0.0,
                            offset: isTouching ? Offset.zero : const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#$number',
                        style: TextStyle(
                          color: isTouching && blinkVal > 0.6 ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    });
  }

  // 5. СОСТАВ
  Widget _buildRosterAndTeamsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('teams_list_$_refreshCounter'),
      future: _teamsFuture,
      builder: (context, teamSnapshot) {
        if (teamSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)));
        }

        if (teamSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Ошибка списка команд: ${teamSnapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          );
        }

        final teams = teamSnapshot.data ?? [];
        if (teams.isNotEmpty && (_activeTeamId == null || !teams.any((t) => t['id'] == _activeTeamId))) {
          _activeTeamId = teams.first['id'].toString();
          _activeTeamName = teams.first['name'].toString();
          _loadTacticsFuture();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _activeTeamName != null ? 'КОМАНДА: $_activeTeamName' : 'КОМАНДЫ',
                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: _openCreateTeamDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB800), foregroundColor: Colors.black),
                    child: const Text('Создать команду'),
                  ),
                ],
              ),
            ),
            if (teams.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: teams.map((t) {
                    final isSel = t['id'].toString() == _activeTeamId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t['name'] ?? ''),
                        selected: isSel,
                        selectedColor: const Color(0xFFFFB800),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _activeTeamId = t['id'].toString();
                              _activeTeamName = t['name'];
                              _onPitchPlayerIds.clear();
                              _resetFormationPositions();
                              _loadTacticsFuture();
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: _activeTeamId == null
                  ? const Center(child: Text('Создайте команду', style: TextStyle(color: Colors.white38)))
                  : _buildPlayersListForTeam(_activeTeamId!),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlayersListForTeam(String teamId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('roster_${teamId}_$_refreshCounter'),
      future: Supabase.instance.client.from('player_profiles').select().eq('team_id', teamId).order('jersey_number'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Ошибка игроков: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          );
        }

        final players = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton(
              onPressed: () => _openCreatePlayerDialog(teamId),
              child: const Text('+ Добавить игрока'),
            ),
            const SizedBox(height: 10),
            if (players.isEmpty)
              const Center(child: Text('Нет игроков в заявке', style: TextStyle(color: Colors.white38)))
            else
              ...players.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141724),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFB800),
                        foregroundColor: Colors.black,
                        child: Text('#${p['jersey_number'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                        '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim().isEmpty
                            ? 'Игрок без имени'
                            : '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Позиция: ${p['position'] ?? 'ST'}', style: const TextStyle(color: Colors.white54)),
                      trailing: Row(
                        mainAxisSize: dynamicMinSize(),
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white60, size: 20),
                            onPressed: () => _openEditPlayerDialog(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () async {
                              await Supabase.instance.client.from('player_profiles').delete().eq('id', p['id']);
                              setState(() {
                                _refreshCounter++;
                                _loadTacticsFuture();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }

  MainAxisSize dynamicMinSize() => MainAxisSize.min;

  void _openCreateTeamDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        title: const Text('Новая команда', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [CapitalizeWordsFormatter()],
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Название команды', labelStyle: TextStyle(color: Colors.white60)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB800), foregroundColor: Colors.black),
            onPressed: () async {
              final n = _capitalizeWords(nameCtrl.text);
              if (n.isEmpty) return;
              Navigator.of(ctx).pop();
              await Supabase.instance.client.from('teams').insert({'name': n});
              setState(() {
                _refreshCounter++;
                _teamsFuture = Supabase.instance.client.from('teams').select().order('name');
              });
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _openCreatePlayerDialog(String teamId) {
    final fNameCtrl = TextEditingController();
    final lNameCtrl = TextEditingController();
    final numCtrl = TextEditingController(text: '10');
    String pos = 'ST';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          backgroundColor: const Color(0xFF141724),
          title: const Text('Новый игрок', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fNameCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [CapitalizeWordsFormatter()],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Имя', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lNameCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [CapitalizeWordsFormatter()],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Фамилия', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: numCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Номер', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: pos,
                dropdownColor: const Color(0xFF141724),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Позиция', labelStyle: TextStyle(color: Colors.white60)),
                items: const [
                  DropdownMenuItem(value: 'GK', child: Text('GK (Вратарь)')),
                  DropdownMenuItem(value: 'DF', child: Text('DF (Защитник)')),
                  DropdownMenuItem(value: 'MF', child: Text('MF (Полузащитник)')),
                  DropdownMenuItem(value: 'ST', child: Text('ST (Нападающий)')),
                ],
                onChanged: (val) {
                  if (val != null) setDState(() => pos = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB800), foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Supabase.instance.client.from('player_profiles').insert({
                  'team_id': teamId,
                  'first_name': _capitalizeWords(fNameCtrl.text),
                  'last_name': _capitalizeWords(lNameCtrl.text),
                  'jersey_number': int.tryParse(numCtrl.text) ?? 10,
                  'position': pos,
                });
                setState(() {
                  _refreshCounter++;
                  _loadTacticsFuture();
                });
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditPlayerDialog(Map<String, dynamic> player) {
    final fNameCtrl = TextEditingController(text: player['first_name'] ?? '');
    final lNameCtrl = TextEditingController(text: player['last_name'] ?? '');
    final numCtrl = TextEditingController(text: '${player['jersey_number'] ?? 10}');
    String pos = player['position'] ?? 'ST';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          backgroundColor: const Color(0xFF141724),
          title: const Text('Редактировать игрока', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fNameCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [CapitalizeWordsFormatter()],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Имя', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lNameCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [CapitalizeWordsFormatter()],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Фамилия', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: numCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Номер', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: pos,
                dropdownColor: const Color(0xFF141724),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Позиция', labelStyle: TextStyle(color: Colors.white60)),
                items: const [
                  DropdownMenuItem(value: 'GK', child: Text('GK (Вратарь)')),
                  DropdownMenuItem(value: 'DF', child: Text('DF (Защитник)')),
                  DropdownMenuItem(value: 'MF', child: Text('MF (Полузащитник)')),
                  DropdownMenuItem(value: 'ST', child: Text('ST (Нападающий)')),
                ],
                onChanged: (val) {
                  if (val != null) setDState(() => pos = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB800), foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Supabase.instance.client.from('player_profiles').update({
                  'first_name': _capitalizeWords(fNameCtrl.text),
                  'last_name': _capitalizeWords(lNameCtrl.text),
                  'jersey_number': int.tryParse(numCtrl.text) ?? 10,
                  'position': pos,
                }).eq('id', player['id']);
                setState(() {
                  _refreshCounter++;
                  _loadTacticsFuture();
                });
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// ГЛАДКИЙ СПЛАЙН-СЛЕД
// -------------------------------------------------------------
class TrajectoryPainter extends CustomPainter {
  final Map<int, List<Offset>> trails;
  final List<Offset> ballTrail;

  TrajectoryPainter({
    required this.trails,
    this.ballTrail = const [],
  });

  void _drawSpline(Canvas canvas, Size size, List<Offset> points, Color color) {
    if (points.length < 2) return;

    final trailPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final pxPoints = points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    final path = Path();
    path.moveTo(pxPoints.first.dx, pxPoints.first.dy);

    if (pxPoints.length == 2) {
      path.lineTo(pxPoints.last.dx, pxPoints.last.dy);
    } else {
      for (int i = 0; i < pxPoints.length - 1; i++) {
        final p0 = i == 0 ? pxPoints[0] : pxPoints[i - 1];
        final p1 = pxPoints[i];
        final p2 = pxPoints[i + 1];
        final p3 = (i + 2 < pxPoints.length) ? pxPoints[i + 2] : p2;

        final c1 = p1 + (p2 - p0) * (1.0 / 6.0);
        final c2 = p2 - (p3 - p1) * (1.0 / 6.0);

        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
      }
    }

    final dashedPath = Path();
    const double dashWidth = 8.0;
    const double dashSpace = 5.0;

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dashWidth, metric.length - distance);
        dashedPath.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, trailPaint);

    final lastMetric = metrics.last;
    final tangent = lastMetric.getTangentForOffset(lastMetric.length);
    if (tangent != null) {
      final double angle = tangent.vector.direction;
      final last = tangent.position;
      const double arrowSize = 11.0;

      final arrowPath = Path()
        ..moveTo(last.dx, last.dy)
        ..lineTo(
          last.dx - arrowSize * math.cos(angle - math.pi / 5.5),
          last.dy - arrowSize * math.sin(angle - math.pi / 5.5),
        )
        ..lineTo(
          last.dx - arrowSize * math.cos(angle + math.pi / 5.5),
          last.dy - arrowSize * math.sin(angle + math.pi / 5.5),
        )
        ..close();

      canvas.drawPath(arrowPath, arrowPaint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in trails.entries) {
      _drawSpline(canvas, size, entry.value, const Color(0xFFFFD54F));
    }

    if (ballTrail.length >= 2) {
      _drawSpline(canvas, size, ballTrail, Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant TrajectoryPainter oldDelegate) => true;
}

// -------------------------------------------------------------
// РАЗМЕТКА ПОЛЕЙ
// -------------------------------------------------------------
class FootballPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgDark = const Color(0xFF1B3B2B);
    final bgLight = const Color(0xFF224734);
    final runOffColor = const Color(0xFF132A1F);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = runOffColor);

    final double padX = 14.0;
    final double padY = 22.0;
    final courtRect = Rect.fromLTWH(padX, padY, size.width - padX * 2, size.height - padY * 2);

    final int stripes = 8;
    final double stripeHeight = courtRect.height / stripes;
    canvas.save();
    canvas.clipPath(Path()..addRect(courtRect));
    for (int i = 0; i < stripes; i++) {
      final stripePaint = Paint()..color = (i % 2 == 0) ? bgDark : bgLight;
      canvas.drawRect(
        Rect.fromLTWH(courtRect.left, courtRect.top + i * stripeHeight, courtRect.width, stripeHeight),
        stripePaint,
      );
    }
    canvas.restore();

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(courtRect, linePaint);
    final double midY = courtRect.top + courtRect.height / 2;
    canvas.drawLine(Offset(courtRect.left, midY), Offset(courtRect.right, midY), linePaint);
    canvas.drawCircle(Offset(size.width / 2, midY), courtRect.width * 0.18, linePaint);
    canvas.drawCircle(Offset(size.width / 2, midY), 3.5, Paint()..color = Colors.white);

    final double goalWidth = courtRect.width * 0.32;
    final double goalLeft = (size.width - goalWidth) / 2;
    const double goalDepth = 12.0;

    canvas.drawRect(Rect.fromLTWH(goalLeft, courtRect.top - goalDepth, goalWidth, goalDepth), linePaint);
    canvas.drawRect(Rect.fromLTWH(goalLeft, courtRect.bottom, goalWidth, goalDepth), linePaint);

    final double boxWidth = courtRect.width * 0.58;
    final double boxLeft = (size.width - boxWidth) / 2;
    final double boxHeight = courtRect.height * 0.16;

    canvas.drawRect(Rect.fromLTWH(boxLeft, courtRect.top, boxWidth, boxHeight), linePaint);
    canvas.drawRect(Rect.fromLTWH(boxLeft, courtRect.bottom - boxHeight, boxWidth, boxHeight), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FutsalPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgDark = const Color(0xFF1E3F2D);
    final bgLight = const Color(0xFF244A36);
    final runOffColor = const Color(0xFF142C1F);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = runOffColor);

    final double padX = 14.0;
    final double padY = 22.0;
    final courtRect = Rect.fromLTWH(padX, padY, size.width - padX * 2, size.height - padY * 2);

    const int stripes = 8;
    final double stripeHeight = courtRect.height / stripes;
    canvas.save();
    canvas.clipPath(Path()..addRect(courtRect));
    for (int i = 0; i < stripes; i++) {
      final stripePaint = Paint()..color = (i % 2 == 0) ? bgDark : bgLight;
      canvas.drawRect(
        Rect.fromLTWH(courtRect.left, courtRect.top + i * stripeHeight, courtRect.width, stripeHeight),
        stripePaint,
      );
    }
    canvas.restore();

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final thinLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    canvas.drawRect(courtRect, linePaint);

    final double midY = courtRect.top + courtRect.height / 2;
    canvas.drawLine(Offset(courtRect.left, midY), Offset(courtRect.right, midY), linePaint);
    final double centerRadius = courtRect.width * 0.17;
    canvas.drawCircle(Offset(size.width / 2, midY), centerRadius, linePaint);
    canvas.drawCircle(Offset(size.width / 2, midY), 3.5, dotPaint);

    const double cornerRadius = 14.0;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(courtRect.left, courtRect.top), radius: cornerRadius),
      0, math.pi / 2, false, linePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(courtRect.right, courtRect.top), radius: cornerRadius),
      math.pi / 2, math.pi / 2, false, linePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(courtRect.right, courtRect.bottom), radius: cornerRadius),
      math.pi, math.pi / 2, false, linePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(courtRect.left, courtRect.bottom), radius: cornerRadius),
      3 * math.pi / 2, math.pi / 2, false, linePaint,
    );

    final double goalWidth = courtRect.width * 0.28;
    final double goalLeft = (size.width - goalWidth) / 2;
    final double goalRight = goalLeft + goalWidth;
    const double goalDepth = 12.0;

    _drawGoal(
      canvas: canvas,
      rect: Rect.fromLTWH(goalLeft, courtRect.top - goalDepth, goalWidth, goalDepth),
      isTop: true,
    );

    _drawGoal(
      canvas: canvas,
      rect: Rect.fromLTWH(goalLeft, courtRect.bottom, goalWidth, goalDepth),
      isTop: false,
    );

    final double radius6m = courtRect.height * 0.16;

    final topDPath = Path();
    topDPath.arcTo(
      Rect.fromCircle(center: Offset(goalLeft, courtRect.top), radius: radius6m),
      math.pi, -math.pi / 2, false,
    );
    topDPath.lineTo(goalRight, courtRect.top + radius6m);
    topDPath.arcTo(
      Rect.fromCircle(center: Offset(goalRight, courtRect.top), radius: radius6m),
      math.pi / 2, -math.pi / 2, false,
    );
    canvas.drawPath(topDPath, linePaint);

    canvas.drawCircle(Offset(size.width / 2, courtRect.top + radius6m), 3.0, dotPaint);

    final double spot10mTop = courtRect.top + radius6m * 1.66;
    canvas.drawCircle(Offset(size.width / 2, spot10mTop), 2.5, dotPaint);
    canvas.drawLine(Offset(size.width / 2 - 4, spot10mTop), Offset(size.width / 2 + 4, spot10mTop), thinLinePaint);

    final bottomDPath = Path();
    bottomDPath.arcTo(
      Rect.fromCircle(center: Offset(goalLeft, courtRect.bottom), radius: radius6m),
      math.pi, math.pi / 2, false,
    );
    bottomDPath.lineTo(goalRight, courtRect.bottom - radius6m);
    bottomDPath.arcTo(
      Rect.fromCircle(center: Offset(goalRight, courtRect.bottom), radius: radius6m),
      3 * math.pi / 2, math.pi / 2, false,
    );
    canvas.drawPath(bottomDPath, linePaint);

    canvas.drawCircle(Offset(size.width / 2, courtRect.bottom - radius6m), 3.0, dotPaint);

    final double spot10mBottom = courtRect.bottom - radius6m * 1.66;
    canvas.drawCircle(Offset(size.width / 2, spot10mBottom), 2.5, dotPaint);
    canvas.drawLine(Offset(size.width / 2 - 4, spot10mBottom), Offset(size.width / 2 + 4, spot10mBottom), thinLinePaint);
  }

  void _drawGoal({required Canvas canvas, required Rect rect, required bool isTop}) {
    final netBgPaint = Paint()..color = Colors.black.withValues(alpha: 0.3);
    canvas.drawRect(rect, netBgPaint);

    final netLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    const double step = 4.0;
    for (double x = rect.left; x <= rect.right; x += step) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), netLinePaint);
    }
    for (double y = rect.top; y <= rect.bottom; y += step) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), netLinePaint);
    }

    final postPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRect(rect, postPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}