import 'dart:async';
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

class _PlayerRunState {
  final int index;
  final bool isOpponent;
  final List<Offset> trail;
  final DateTime startTime;
  final int durationMs;

  _PlayerRunState({
    required this.index,
    required this.isOpponent,
    required this.trail,
    required this.startTime,
    this.durationMs = 1470,
  });
}

class _AcademyHubScreenState extends State<AcademyHubScreen> with TickerProviderStateMixin {
  int _selectedTab = 0;
  int _refreshCounter = 0;
  bool _isFullscreenTactics = false;
  bool _showHeatmap = false; 
  bool _showOpponents = true; // Отображение команды соперников
  bool _showBall = true; // Отображение мяча на поле

  // Демо-режим
  bool _isDemoMode = false;
  int _selectedDemoScenario = 0; // 0: Скучивание, 1: Провал тыла, 2: Вратарь зажат
  bool _demoShowCorrect = false;

  late AnimationController _demoAnimController;
  List<Offset> _demoStartPositionsTeamA = [];
  List<Offset> _demoTargetPositionsTeamA = [];
  List<Offset> _demoStartPositionsTeamB = [];
  List<Offset> _demoTargetPositionsTeamB = [];
  Offset _demoStartBall = const Offset(0.5, 0.5);
  Offset _demoTargetBall = const Offset(0.5, 0.5);

  String _sportType = 'futsal'; 
  String? _activeTeamId;
  String? _activeTeamName;

  String _selectedFutsalFormation = '1-2-1';
  String _selectedFootballFormation = '2-3-1';

  final List<String> _futsalFormations = [
    '1-2-1',
    '2-2',
    '3-1',
    '4-0',
    '5-0',
  ];

  final List<String> _footballFormations = [
    '2-3-1',
    '3-2-1',
    '2-2-2',
  ];

  List<Offset> _pitchPositions = []; // Наша команда (Синие)
  List<Offset> _opponentPositions = []; // Соперники (Красные)
  List<String> _onPitchPlayerIds = [];

  // Мяч
  Offset _ballPosition = const Offset(0.50, 0.50);
  final List<Offset> _ballTrail = [];

  // Интерактивное перемещение игроков
  int? _movingPlayerIndex;
  List<Offset> _activePlayerTrail = [];
  final Map<String, _PlayerRunState> _runningPlayers = {};
  // --- РЕЖИМ МАТЧА (MATCH ENGINE) ---
  bool _isMatchMode = false;
  bool _showAnalyticsLayer = false;
  bool _showPitchControlLayer = false;
  bool _enableTacticalAI = true;
  int _aiDecisionTicks = 0;
  int? _lastPasserIndex;
  bool _lastPasserIsOpponent = false;
  int _passIgnoreTicks = 0;
  DateTime? _pitchPointerDownTime;
  Offset? _pitchPointerDownPos;
  int _blueScore = 0;
  int _redScore = 0;
  double _blueXG = 0.0;
  double _redXG = 0.0;
  int _bluePossessionTicks = 1;
  int _redPossessionTicks = 1;
  String _matchTelemetryText = 'Готовность к матчу • xG и телеметрия активны';
  int _matchSeconds = 300;
  bool _isMatchTimerActive = false;
  Timer? _matchTicker;
  int _matchPhysicsCounter = 0;
  bool _showGoalBanner = false;
  String _goalScorerText = '';
  Offset? _freeBallVelocity;
  bool _lastShotByOpponent = false;
  DateTime _lastTackleTime = DateTime.now();
  final Map<String, Offset> _prevPlayerPositions = {};
  final Map<String, Offset> _playerHeadings = {};
  final Map<String, List<Offset>> _playerTrails = {};
  final Set<String> _activeTouchPlayerKeys = {};

  String _playerKey(int index, bool isOpponent) => '${isOpponent ? "opp" : "team"}_$index';
  
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  late AnimationController _moveController;
  late AnimationController _fadeController;
  late AnimationController _passController;
  int? _ballPossessorIndex;
  bool _ballPossessorIsOpponent = false;
  int? _selectedPlayerForBall;
  bool _selectedPlayerForBallIsOpponent = false;
  int? _pendingPassTargetIndex;
  bool _pendingPassTargetIsOpponent = false;
  List<Offset> _ballPassTrail = [];

  Future<List<Map<String, dynamic>>>? _tacticsFuture;
  Future<List<Map<String, dynamic>>>? _calendarFuture;
  Future<List<Map<String, dynamic>>>? _teamsFuture;
  Future<List<Map<String, dynamic>>>? _scorersFuture;

  @override
  void initState() {
    super.initState();

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1470),
    );

    _moveController.addListener(() {
      if (_runningPlayers.isEmpty) {
        if (_moveController.isAnimating) _moveController.stop();
        return;
      }

      final now = DateTime.now();
      final finishedKeys = <String>[];

      setState(() {
        for (final entry in _runningPlayers.entries) {
          final runner = entry.value;
          final elapsed = now.difference(runner.startTime).inMilliseconds;
          final linearProgress = (elapsed / runner.durationMs).clamp(0.0, 1.0);
          final curveProgress = Curves.easeInOutCubic.transform(linearProgress);

          final currentPos = _samplePathPoint(runner.trail, curveProgress);

          if (runner.isOpponent) {
            if (runner.index < _opponentPositions.length) {
              _opponentPositions[runner.index] = currentPos;
            }
          } else {
            if (runner.index < _pitchPositions.length) {
              _pitchPositions[runner.index] = currentPos;
            }
          }

          if (_ballPossessorIndex == runner.index && _ballPossessorIsOpponent == runner.isOpponent) {
            if (!_checkAndHandleTackle(currentPos, isOpponent: runner.isOpponent)) {
              _ballPosition = _getDribbleBallPosition(currentPos, runner.isOpponent);
            }
          } else if (_showBall && _ballPossessorIndex == null && (currentPos - _ballPosition).distance < 0.045) {
            _ballPossessorIndex = runner.index;
            _ballPossessorIsOpponent = runner.isOpponent;
            _ballPosition = _getDribbleBallPosition(currentPos, runner.isOpponent);
            _blinkController.repeat(reverse: true);
          }

          if (linearProgress >= 1.0) {
            finishedKeys.add(entry.key);
          }
        }

        for (final key in finishedKeys) {
          final runner = _runningPlayers.remove(key)!;
          final endPos = runner.trail.last;

          if (runner.isOpponent) {
            if (runner.index < _opponentPositions.length) {
              _opponentPositions[runner.index] = endPos;
            }
          } else {
            if (runner.index < _pitchPositions.length) {
              _pitchPositions[runner.index] = endPos;
            }
          }

          if (_selectedPlayerForBall != null &&
              runner.index == _selectedPlayerForBall &&
              runner.isOpponent == _selectedPlayerForBallIsOpponent) {
            _ballPossessorIndex = _selectedPlayerForBall;
            _ballPossessorIsOpponent = _selectedPlayerForBallIsOpponent;
            _ballPosition = _getDribbleBallPosition(endPos, runner.isOpponent);
            _selectedPlayerForBall = null;
            _blinkController.repeat(reverse: true);
          } else if (_ballPossessorIndex == null && (endPos - _ballPosition).distance < 0.055) {
            _ballPossessorIndex = runner.index;
            _ballPossessorIsOpponent = runner.isOpponent;
            _ballPosition = _getDribbleBallPosition(endPos, runner.isOpponent);
            _selectedPlayerForBall = null;
            _blinkController.repeat(reverse: true);
          } else if (_ballPossessorIndex == runner.index && _ballPossessorIsOpponent == runner.isOpponent) {
            _ballPosition = _getDribbleBallPosition(endPos, runner.isOpponent);
          }

          _playerTrails.remove(key);
        }
      });

      if (finishedKeys.isNotEmpty) {
        HapticFeedback.selectionClick();
        _fadeController.forward(from: 0.0);
      }

      if (_runningPlayers.isEmpty) {
        _moveController.stop();
        _movingPlayerIndex = null;
        if (_ballPossessorIndex == null) {
          _blinkController.stop();
        }
      }
    });
    _activeTeamId = widget.myTeamId;

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _blinkAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _movingPlayerIndex = null; _runningPlayers.clear(); _playerTrails.clear(); _activeTouchPlayerKeys.clear();
    _passController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _passController.addListener(() {
      if (_ballPassTrail.length >= 2) {
        setState(() {
          _ballPosition = Offset.lerp(
            _ballPassTrail[0],
            _ballPassTrail[1],
            Curves.easeOutCubic.transform(_passController.value),
          )!;
        });
      }
    });
    _passController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_pendingPassTargetIndex != null) {
          setState(() {
            _ballPossessorIndex = _pendingPassTargetIndex;
            _ballPossessorIsOpponent = _pendingPassTargetIsOpponent;
            final pPos = _pendingPassTargetIsOpponent
                ? _opponentPositions[_pendingPassTargetIndex!]
                : _pitchPositions[_pendingPassTargetIndex!];
            _ballPosition = Offset(
              (pPos.dx + 0.052).clamp(0.04, 0.96),
              (pPos.dy + 0.016).clamp(0.04, 0.96),
            );
            _selectedPlayerForBall = null;
            _pendingPassTargetIndex = null;
          });
          _blinkController.repeat(reverse: true);
        } else {
          setState(() {
            _ballPossessorIndex = null;
            _ballPossessorIsOpponent = false;
            _selectedPlayerForBall = null;
            _pendingPassTargetIndex = null;
            _movingPlayerIndex = null;
          });
          _blinkController.stop();
        }
      }
    });
      _ballPossessorIsOpponent = false;
      _selectedPlayerForBallIsOpponent = false;
      _pendingPassTargetIsOpponent = false;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeController.addListener(() => setState(() {}));

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _activePlayerTrail.clear();
        });
      }
    });

    _demoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _demoAnimController.addListener(() {
      final t = CurvedAnimation(parent: _demoAnimController, curve: Curves.easeInOutCubic).value;
      if (_demoStartPositionsTeamA.length == _pitchPositions.length &&
          _demoTargetPositionsTeamA.length == _pitchPositions.length) {
        setState(() {
          for (int i = 0; i < _pitchPositions.length; i++) {
            _pitchPositions[i] = Offset.lerp(_demoStartPositionsTeamA[i], _demoTargetPositionsTeamA[i], t)!;
          }
          for (int i = 0; i < _opponentPositions.length; i++) {
            _opponentPositions[i] = Offset.lerp(_demoStartPositionsTeamB[i], _demoTargetPositionsTeamB[i], t)!;
          }
          _ballPosition = Offset.lerp(_demoStartBall, _demoTargetBall, t)!;
        });
      }
    });

    _resetFormationPositions();
    _loadAllFutures();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _moveController.dispose();
    _fadeController.dispose();
    _passController.dispose();
    _demoAnimController.dispose();
        _matchTicker?.cancel();
    super.dispose();
  }

  Offset _samplePathPoint(List<Offset> pts, double t) {
    if (pts.isEmpty) return const Offset(0.5, 0.5);
    if (pts.length == 1) return pts.first;

    double totalDist = 0.0;
    final distances = <double>[];
    for (int i = 0; i < pts.length - 1; i++) {
      final d = (pts[i + 1] - pts[i]).distance;
      distances.add(d);
      totalDist += d;
    }

    if (totalDist == 0.0) return pts.last;

    final targetDist = totalDist * t;
    double currentDist = 0.0;

    for (int i = 0; i < distances.length; i++) {
      if (currentDist + distances[i] >= targetDist) {
        final segmentFraction = (targetDist - currentDist) / distances[i];
        return Offset.lerp(pts[i], pts[i + 1], segmentFraction) ?? pts[i + 1];
      }
      currentDist += distances[i];
    }
    return pts.last;
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

    _moveController.stop();
    _passController.stop();
    _blinkController.stop();

    setState(() {
      _pitchPositions = _getDefaultPositions(isFutsal, form, isOpponent: false);
      _opponentPositions = _getDefaultPositions(isFutsal, form, isOpponent: true);
      _ballPosition = const Offset(0.50, 0.50);

      _ballPossessorIndex = null;
      _ballPossessorIsOpponent = false;
      _selectedPlayerForBallIsOpponent = false;
      _pendingPassTargetIsOpponent = false;
      _selectedPlayerForBall = null;
      _pendingPassTargetIndex = null;

      _movingPlayerIndex = null;

      _activePlayerTrail.clear();
      _ballPassTrail.clear();
      _ballTrail.clear();
    });

    HapticFeedback.lightImpact();
  }

  void _resetBallToCenter() {
    _passController.stop();

    setState(() {
        _showBall = true;
      _ballPosition = const Offset(0.50, 0.50);
      _ballPossessorIndex = null;
      _ballPossessorIsOpponent = false;
      _selectedPlayerForBallIsOpponent = false;
      _pendingPassTargetIsOpponent = false;
      _selectedPlayerForBall = null;
      _pendingPassTargetIndex = null;
      _ballPassTrail.clear();
      _ballTrail.clear();
    });

    if (_movingPlayerIndex == null) {
      _blinkController.stop();
    }

    HapticFeedback.lightImpact();
  }

  // ДЕМОНСТРАЦИОННЫЙ РЕЖИМ С ДВУМЯ КОМАНДАМИ
  void _applyDemoState({required int scenarioIndex, required bool showCorrect}) {
    HapticFeedback.selectionClick();
    final count = _sportType == 'futsal' ? 5 : 7;
    List<Offset> targetsTeamA = [];
    List<Offset> targetsTeamB = [];
    Offset targetBall = const Offset(0.5, 0.5);

    if (scenarioIndex == 0) {
      // 1. СКУЧИВАНИЕ (4 СИНИХ ЗА МЯЧОМ VS КРАСНЫЕ В ЛОВУШКЕ И НА ФЛАНГАХ)
      if (!showCorrect) {
        targetBall = const Offset(0.35, 0.44);
        if (count == 5) {
          targetsTeamA = [
            const Offset(0.50, 0.88), // Вратарь Синих
            const Offset(0.36, 0.46), // Синий 1
            const Offset(0.32, 0.42), // Синий 2
            const Offset(0.40, 0.40), // Синий 3
            const Offset(0.31, 0.48), // Синий 4
          ];
          targetsTeamB = [
            const Offset(0.50, 0.12), // Вратарь Красных
            const Offset(0.40, 0.45), // Красный окружает кучу
            const Offset(0.30, 0.40), // Красный блокирует
            const Offset(0.82, 0.42), // Красный СВОБОДЕН НА ПРАВОМ ФЛАНГЕ!
            const Offset(0.68, 0.60), // Красный свободен под контратаку!
          ];
        } else {
          targetsTeamA = [
            const Offset(0.50, 0.90),
            const Offset(0.36, 0.46),
            const Offset(0.32, 0.42),
            const Offset(0.40, 0.40),
            const Offset(0.31, 0.48),
            const Offset(0.42, 0.45),
            const Offset(0.28, 0.42),
          ];
          targetsTeamB = [
            const Offset(0.50, 0.10),
            const Offset(0.40, 0.45),
            const Offset(0.30, 0.40),
            const Offset(0.85, 0.42),
            const Offset(0.70, 0.62),
            const Offset(0.55, 0.42),
            const Offset(0.50, 0.30),
          ];
        }
      } else {
        // Как надо: Синие широко, Красные растянуты, коридоры открыты
        targetBall = const Offset(0.20, 0.48);
        if (count == 5) {
          targetsTeamA = [
            const Offset(0.50, 0.88),
            const Offset(0.50, 0.70), // Страхующий
            const Offset(0.20, 0.48), // Левый фланг с мячом
            const Offset(0.80, 0.48), // Правый фланг в ширине
            const Offset(0.50, 0.22), // Нападающий
          ];
          targetsTeamB = [
            const Offset(0.50, 0.12),
            const Offset(0.50, 0.34),
            const Offset(0.28, 0.50), // Красный тянется к мячу
            const Offset(0.72, 0.50), // Красный держит правый фланг
            const Offset(0.45, 0.62),
          ];
        } else {
          targetsTeamA = [
            const Offset(0.50, 0.90),
            const Offset(0.30, 0.72),
            const Offset(0.70, 0.72),
            const Offset(0.20, 0.48),
            const Offset(0.50, 0.48),
            const Offset(0.82, 0.48),
            const Offset(0.50, 0.22),
          ];
          targetsTeamB = [
            const Offset(0.50, 0.10),
            const Offset(0.35, 0.30),
            const Offset(0.65, 0.30),
            const Offset(0.28, 0.50),
            const Offset(0.72, 0.50),
            const Offset(0.50, 0.40),
            const Offset(0.45, 0.60),
          ];
        }
      }
    } else if (scenarioIndex == 1) {
      // 2. ПРОВАЛ ТЫЛА (КОНТРАТАКА КРАСНЫХ 2-В-1)
      if (!showCorrect) {
        targetBall = const Offset(0.46, 0.40);
        if (count == 5) {
          targetsTeamA = [
            const Offset(0.50, 0.90), // Одинокий вратарь Синих
            const Offset(0.26, 0.20), // Все синие застряли впереди
            const Offset(0.44, 0.18),
            const Offset(0.70, 0.20),
            const Offset(0.50, 0.14),
          ];
          targetsTeamB = [
            const Offset(0.50, 0.12),
            const Offset(0.50, 0.24),
            const Offset(0.46, 0.40), // Красный убегает с мячом
            const Offset(0.35, 0.65), // Красный нападающий 1 на 1!
            const Offset(0.65, 0.65), // Красный нападающий 2 на 1!
          ];
        } else {
          targetsTeamA = [
            const Offset(0.50, 0.90),
            const Offset(0.25, 0.20),
            const Offset(0.40, 0.18),
            const Offset(0.60, 0.20),
            const Offset(0.75, 0.22),
            const Offset(0.45, 0.14),
            const Offset(0.55, 0.14),
          ];
          targetsTeamB = [
            const Offset(0.50, 0.10),
            const Offset(0.30, 0.22),
            const Offset(0.70, 0.22),
            const Offset(0.46, 0.40),
            const Offset(0.35, 0.65),
            const Offset(0.65, 0.65),
            const Offset(0.50, 0.50),
          ];
        }
      } else {
        targetBall = const Offset(0.50, 0.26);
        if (count == 5) {
          targetsTeamA = [
            const Offset(0.50, 0.88),
            const Offset(0.50, 0.62), // Страхующий защитник блокирует
            const Offset(0.22, 0.38),
            const Offset(0.78, 0.38),
            const Offset(0.50, 0.22),
          ];
          targetsTeamB = [
            const Offset(0.50, 0.12),
            const Offset(0.50, 0.30),
            const Offset(0.30, 0.45),
            const Offset(0.70, 0.45),
            const Offset(0.50, 0.52), // Перекрыт защитником
          ];
        } else {
          targetsTeamA = [
            const Offset(0.50, 0.90),
            const Offset(0.35, 0.68),
            const Offset(0.65, 0.68),
            const Offset(0.20, 0.42),
            const Offset(0.50, 0.38),
            const Offset(0.80, 0.42),
            const Offset(0.50, 0.22),
          ];
          targetsTeamB = [
            const Offset(0.50, 0.10),
            const Offset(0.35, 0.32),
            const Offset(0.65, 0.32),
            const Offset(0.25, 0.50),
            const Offset(0.75, 0.50),
            const Offset(0.40, 0.58),
            const Offset(0.60, 0.58),
          ];
        }
      }
    } else {
      // 3. ВЫСОКИЙ ПРЕССИНГ КРАСНЫХ У ВОРОТ ВРАТАРЯ
      if (!showCorrect) {
        targetBall = const Offset(0.50, 0.86);
        if (count == 5) {
          targetsTeamA = [
            const Offset(0.50, 0.88), // Вратарь с мячом
            const Offset(0.48, 0.76), // Закрыт
            const Offset(0.52, 0.74), // Закрыт
            const Offset(0.46, 0.50),
            const Offset(0.54, 0.48),
          ];
          targetsTeamB = [
            const Offset(0.50, 0.12),
            const Offset(0.50, 0.30),
            const Offset(0.48, 0.70), // Красный прессингует вратаря
            const Offset(0.44, 0.78), // Красный опекает вплотную
            const Offset(0.56, 0.76), // Красный опекает вплотную
          ];
        } else {
          targetsTeamA = [
            const Offset(0.50, 0.90),
            const Offset(0.48, 0.78),
            const Offset(0.52, 0.76),
            const Offset(0.46, 0.60),
            const Offset(0.54, 0.58),
            const Offset(0.48, 0.40),
            const Offset(0.52, 0.38),
          ];
          targetsTeamB = [
            const Offset(0.50, 0.10),
            const Offset(0.50, 0.28),
            const Offset(0.50, 0.68),
            const Offset(0.44, 0.80),
            const Offset(0.56, 0.78),
            const Offset(0.42, 0.62),
            const Offset(0.58, 0.60),
          ];
        }
      } else {
        targetBall = const Offset(0.50, 0.88);
        if (count == 5) {
          targetsTeamA = [
            const Offset(0.50, 0.88),
            const Offset(0.16, 0.74), // Синий открылся на фланг
            const Offset(0.84, 0.74), // Синий открылся на фланг
            const Offset(0.50, 0.52),
            const Offset(0.50, 0.25),
          ];
          targetsTeamB = [
            const Offset(0.50, 0.12),
            const Offset(0.50, 0.34),
            const Offset(0.50, 0.70), // Красный застрял в центре
            const Offset(0.30, 0.76),
            const Offset(0.70, 0.76),
          ];
        } else {
          targetsTeamA = [
            const Offset(0.50, 0.90),
            const Offset(0.16, 0.74),
            const Offset(0.84, 0.74),
            const Offset(0.50, 0.60),
            const Offset(0.25, 0.42),
            const Offset(0.75, 0.42),
            const Offset(0.50, 0.24),
          ];
          targetsTeamB = [
            const Offset(0.50, 0.10),
            const Offset(0.50, 0.30),
            const Offset(0.50, 0.72),
            const Offset(0.30, 0.76),
            const Offset(0.70, 0.76),
            const Offset(0.35, 0.48),
            const Offset(0.65, 0.48),
          ];
        }
      }
    }

    _demoStartPositionsTeamA = List.from(_pitchPositions);
    _demoTargetPositionsTeamA = targetsTeamA;
    _demoStartPositionsTeamB = List.from(_opponentPositions);
    _demoTargetPositionsTeamB = targetsTeamB;
    _demoStartBall = _ballPosition;
    _demoTargetBall = targetBall;
    _selectedDemoScenario = scenarioIndex;
    _demoShowCorrect = showCorrect;
    _isDemoMode = true;
    _showOpponents = true;

    _demoAnimController.forward(from: 0.0);
  }

  String _capitalizeWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1) : '');
    }).join(' ');
  }

  List<Offset> _getDefaultPositions(bool isFutsal, String formation, {required bool isOpponent}) {
    List<Offset> base;
    if (isFutsal) {
      switch (formation) {
        case '2-2':
          base = [
            const Offset(0.50, 0.88),
            const Offset(0.28, 0.65),
            const Offset(0.72, 0.65),
            const Offset(0.28, 0.32),
            const Offset(0.72, 0.32),
          ];
          break;
        case '3-1':
          base = [
            const Offset(0.50, 0.88),
            const Offset(0.20, 0.64),
            const Offset(0.50, 0.72),
            const Offset(0.80, 0.64),
            const Offset(0.50, 0.22),
          ];
          break;
        case '4-0':
          base = [
            const Offset(0.50, 0.88),
            const Offset(0.16, 0.50),
            const Offset(0.38, 0.58),
            const Offset(0.62, 0.58),
            const Offset(0.84, 0.50),
          ];
          break;
        case '5-0':
          base = [
            const Offset(0.50, 0.62),
            const Offset(0.18, 0.38),
            const Offset(0.82, 0.38),
            const Offset(0.32, 0.20),
            const Offset(0.68, 0.20),
          ];
          break;
        case '1-2-1':
        default:
          base = [
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
          base = [
            const Offset(0.50, 0.90),
            const Offset(0.22, 0.72),
            const Offset(0.50, 0.74),
            const Offset(0.78, 0.72),
            const Offset(0.32, 0.46),
            const Offset(0.68, 0.46),
            const Offset(0.50, 0.22),
          ];
          break;
        case '2-2-2':
          base = [
            const Offset(0.50, 0.90),
            const Offset(0.30, 0.72),
            const Offset(0.70, 0.72),
            const Offset(0.30, 0.48),
            const Offset(0.70, 0.48),
            const Offset(0.32, 0.22),
            const Offset(0.68, 0.22),
          ];
          break;
        case '2-3-1':
        default:
          base = [
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

    if (!isOpponent) return base;

    // Зеркальное отображение для соперников (противоположная половина поля)
    return base.map((p) => Offset(p.dx, (1.0 - p.dy).clamp(0.08, 0.92))).toList();
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
      {'title': 'Тактика', 'icon': Icons.dashboard_outlined, 'selectedIcon': Icons.dashboard},
      {'title': 'Таблица', 'icon': Icons.emoji_events_outlined, 'selectedIcon': Icons.emoji_events},
      {'title': 'Календарь', 'icon': Icons.calendar_month_outlined, 'selectedIcon': Icons.calendar_month},
      {'title': 'Бомбардиры', 'icon': Icons.military_tech_outlined, 'selectedIcon': Icons.military_tech},
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
            flex: isSelected ? 3 : 1,
            child: Tooltip(
              message: tab['title'] as String,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFB800) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFB800).withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? tab['selectedIcon'] as IconData : tab['icon'] as IconData,
                        size: 17,
                        color: isSelected ? Colors.black : Colors.white60,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            tab['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
          return _buildTacticsTab(isFullscreen: false);
      case 1:
          return _buildStandingsTab();
      case 2:
          return _buildCalendarTab();
      case 3:
          return _buildTopScorersTab();
      case 4:
          return _buildRosterAndTeamsTab();
      default:
        return const SizedBox.shrink();
    }
  }

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

  // ТАКТИКА (ИНТЕРАКТИВНОЕ ПОЛЕ С 2 КОМАНДАМИ И ДЕМО-РЕЖИМОМ)
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
          _pitchPositions = _getDefaultPositions(isFutsal, currentFormation, isOpponent: false);
        }
        if (_opponentPositions.length != targetStartersCount) {
          _opponentPositions = _getDefaultPositions(isFutsal, currentFormation, isOpponent: true);
        }

        return Column(
          children: [
            // ПАНЕЛЬ УПРАВЛЕНИЯ
              // ПАНЕЛЬ УПРАВЛЕНИЯ И ВЫБОРА СХЕМЫ (ЧИПСЫ + ДЕЙСТВИЯ)
              Container(
                margin: EdgeInsets.fromLTRB(isFullscreen ? 10 : 16, 4, isFullscreen ? 10 : 16, 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF141724),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // СТРОКА 1: ГОРИЗОНТАЛЬНАЯ ЛЕНТА ВСЕХ СХЕМ РАССТАНОВКИ
                    Row(
                      children: [
                        const Icon(Icons.alt_route, color: Color(0xFFFFB800), size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'СХЕМА:',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: formationsList.map((f) {
                                final isSelected = f == currentFormation;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (isFutsal) {
                                          _selectedFutsalFormation = f;
                                        } else {
                                          _selectedFootballFormation = f;
                                        }
                                        _resetFormationPositions();
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFFFB800)
                                            : const Color(0xFF1E2235),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFFFFB800)
                                              : Colors.white.withValues(alpha: 0.12),
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFFFB800).withValues(alpha: 0.35),
                                                  blurRadius: 6,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        f,
                                        style: TextStyle(
                                          color: isSelected ? Colors.black : Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 4),

                    // СТРОКА 2: ИНСТРУМЕНТЫ И РЕЖИМЫ ТАКТИКИ
                    Row(
                      children: [
                        if (isFullscreen) ...[
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => setState(() => _isFullscreenTactics = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB800),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fullscreen_exit, size: 16, color: Colors.black),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        Text(
                          isFutsal ? '⚽ Футзал (5x5)' : '⚽ Футбол (7x7)',
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(width: 8),

                        // Адаптивная горизонтальная лента кнопок управления (без overflow на телефонах)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Кнопка показать/скрыть соперников
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    tooltip: _showOpponents ? 'Скрыть команду соперников' : 'Показать соперников (Красные)',
                                    icon: Icon(
                                      Icons.people_alt,
                                      color: _showOpponents ? const Color(0xFFFF5252) : Colors.white60,
                                      size: 19,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _showOpponents = !_showOpponents;
                                        if (!_showOpponents && _ballPossessorIsOpponent) {
                                          _ballPossessorIndex = null;
                                          _ballPossessorIsOpponent = false;
                                          _selectedPlayerForBall = null;
                                          _blinkController.stop();
                                        }
                                      });
                                    },
                                  ),
                                  // Кнопка убрать/показать мяч на поле
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    tooltip: _showBall ? 'Убрать мяч с поля' : 'Вернуть мяч на поле',
                                    icon: Icon(
                                      Icons.sports_soccer,
                                      color: _showBall ? Colors.white : Colors.white38,
                                      size: 19,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _showBall = !_showBall;
                                        if (!_showBall) {
                                          _ballPossessorIndex = null;
                                          _ballPossessorIsOpponent = false;
                                          _selectedPlayerForBall = null;
                                          _pendingPassTargetIndex = null;
                                          _ballPassTrail.clear();
                                          _blinkController.stop();
                                        }
                                      });
                                    },
                                  ),
                                  // Демо: разбор ошибок
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    tooltip: _isDemoMode ? 'Закрыть демо-режим' : 'Демо: разбор ошибок',
                                    icon: Icon(
                                      Icons.school,
                                      color: _isDemoMode ? const Color(0xFFFFD54F) : Colors.white60,
                                      size: 19,
                                    ),
                                    onPressed: () {
                                      if (_isDemoMode) {
                                        _resetFormationPositions();
                                      } else {
                                        _applyDemoState(scenarioIndex: 0, showCorrect: false);
                                      }
                                    },
                                  ),
                                  // Тепловая карта
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    tooltip: _showHeatmap ? 'Скрыть тепловую карту' : 'Тепловая карта',
                                    icon: Icon(
                                      _showHeatmap ? Icons.whatshot : Icons.whatshot_outlined,
                                      color: _showHeatmap ? const Color(0xFFFF5722) : Colors.white60,
                                      size: 19,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _showHeatmap = !_showHeatmap);
                                    },
                                  ),
                                  // Мяч в центр
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    tooltip: 'Мяч в центр',
                                    icon: const Icon(Icons.sports_soccer, color: Colors.white, size: 18),
                                    onPressed: _resetBallToCenter,
                                  ),
                                  // Сбросить схему
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    tooltip: 'Сбросить схему',
                                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                                    onPressed: _resetFormationPositions,
                                  ),
                                  if (!isFullscreen)
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                      tooltip: 'Развернуть на весь экран',
                                      icon: const Icon(Icons.fullscreen, color: Color(0xFFFFB800), size: 21),
                                      onPressed: () => setState(() => _isFullscreenTactics = true),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ПАНЕЛЬ ПЕРЕКЛЮЧЕНИЯ ДЕМОНСТРАЦИОННОГО РЕЖИМА
            if (_isDemoMode)
              Container(
                margin: EdgeInsets.fromLTRB(isFullscreen ? 10 : 16, 0, isFullscreen ? 10 : 16, 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2235),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school, color: Color(0xFFFFB800), size: 17),
                        const SizedBox(width: 6),
                        const Text('ДЕМО ОШИБОК:', style: TextStyle(color: Color(0xFFFFB800), fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildDemoChip(0, '⚽ Скучивание'),
                                const SizedBox(width: 6),
                                _buildDemoChip(1, '🛡️ Провал тыла'),
                                const SizedBox(width: 6),
                                _buildDemoChip(2, '🧤 Прессинг вратаря'),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _resetFormationPositions,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _applyDemoState(scenarioIndex: _selectedDemoScenario, showCorrect: false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: !_demoShowCorrect ? const Color(0xFFD32F2F) : Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Text('❌ Как не надо (Ошибка)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _applyDemoState(scenarioIndex: _selectedDemoScenario, showCorrect: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: _demoShowCorrect ? const Color(0xFF2E7D32) : Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Text('✅ Как надо (Шире!)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ИГРОВОЕ ПОЛЕ
            if (_isMatchMode) _buildMatchScoreboard(),
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
                        final double fadeAlpha = _fadeController.isAnimating
                            ? (1.0 - _fadeController.value).clamp(0.0, 1.0)
                            : 1.0;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // 1. Поле
                            CustomPaint(
                              size: Size(constraints.maxWidth, constraints.maxHeight),
                              painter: isFutsal ? FutsalPitchPainter() : FootballPitchPainter(),
                            ),

                            // 2. Тепловая карта и зоны ответственности (Синие)
                            if (_showHeatmap)
                              CustomPaint(
                                size: Size(constraints.maxWidth, constraints.maxHeight),
                                painter: HeatmapZonesPainter(
                                  positions: _pitchPositions,
                                  starters: starters,
                                  isFutsal: isFutsal,
                                ),
                              ),

                            // 3. Маркер зоны скучивания
                            if (_isDemoMode && _selectedDemoScenario == 0 && !_demoShowCorrect)
                              CustomPaint(
                                size: Size(constraints.maxWidth, constraints.maxHeight),
                                painter: ClusterWarningPainter(),
                              ),

                            // 4. Пунктирная траектория перемещения игрока со стрелкой
                            CustomPaint(
                              size: Size(constraints.maxWidth, constraints.maxHeight),
                              painter: TrajectoryPainter(
                                playerTrail: _activePlayerTrail,
                  passTrail: _ballPassTrail,
                                ballTrail: _ballTrail,
                                trailAlpha: fadeAlpha,
                              ),
                            ),

                            // 5. Фишки Нашей команды (Синие)
                            _buildDraggableBallNode(constraints: constraints),
                            ..._buildTeamPlayerNodes(
                              constraints: constraints,
                              positions: _pitchPositions,
                              isOpponent: false,
                              starters: starters,
                            ),

                            // 6. Фишки Соперников (Красные)
                            if (_showOpponents)
                              ..._buildTeamPlayerNodes(
                                constraints: constraints,
                                positions: _opponentPositions,
                                isOpponent: true,
                                starters: const [],
                              ),

                            // 7. Мяч

                            // 8. Поясняющая плашка в демо-режиме
                            if (_isDemoMode)
                              Positioned(
                                top: 10,
                                left: 10,
                                right: 100,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _demoShowCorrect ? Colors.greenAccent : Colors.redAccent,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    _getDemoAdviceText(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.25),
                                  ),
                                ),
                              ),

                            // 9. Кнопка «На весь экран»
                            // 9. Кнопка «На весь экран»
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Material(
                                color: isFullscreen ? const Color(0xFFFFB800) : Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(() => _isFullscreenTactics = !_isFullscreenTactics),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    child: Icon(
                                      isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                      color: isFullscreen ? Colors.black : const Color(0xFFFFB800),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // 10. Кнопка возврата расстановки к исходному состоянию
                            Positioned(
                              top: 48,
                              right: 10,
                              child: Tooltip(
                                message: 'Вернуть в исходное положение',
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      HapticFeedback.mediumImpact();
                                      _resetFormationPositions();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      child: const Icon(
                                        Icons.refresh,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // 10a. Неблокирующий детектор быстрого паса тапом по партнеру или коридору xPass
                            Positioned.fill(
                              child: Listener(
                                behavior: HitTestBehavior.translucent,
                                onPointerDown: (event) {
                                  _pitchPointerDownTime = DateTime.now();
                                  _pitchPointerDownPos = event.localPosition;
                                },
                                onPointerUp: (event) {
                                  if (_pitchPointerDownTime != null && _pitchPointerDownPos != null) {
                                    final elapsed = DateTime.now().difference(_pitchPointerDownTime!).inMilliseconds;
                                    final moved = (event.localPosition - _pitchPointerDownPos!).distance;
                                    if (elapsed < 260 && moved < 14.0) {
                                      _handlePitchQuickTap(
                                        event.localPosition,
                                        Size(constraints.maxWidth, constraints.maxHeight),
                                      );
                                    }
                                  }
                                },
                                child: const SizedBox.expand(),
                              ),
                            ),

                            // 10b. Аналитический слой: Контроль поля (Voronoi) + Коридоры паса (xPass %) + Линии обороны
                            if (_showAnalyticsLayer || _showPitchControlLayer)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _TacticalAnalyticsPainter(
                                      bluePositions: List<Offset>.from(_pitchPositions),
                                      redPositions: List<Offset>.from(_opponentPositions),
                                      ballPosition: _ballPosition,
                                      ballPossessorIndex: _ballPossessorIndex,
                                      ballPossessorIsOpponent: _ballPossessorIsOpponent,
                                      showBall: _showBall,
                                      showPassingLanes: _showAnalyticsLayer,
                                      showPitchControl: _showPitchControlLayer,
                                    ),
                                  ),
                                ),
                              ),

                            // 10c. Кнопка включения коридоров паса (xPass + Линии обороны)
                            Positioned(
                              top: 48,
                              left: 10,
                              child: Material(
                                color: _showAnalyticsLayer
                                    ? const Color(0xFF00E676)
                                    : Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _showAnalyticsLayer = !_showAnalyticsLayer;
                                      if (_showAnalyticsLayer) {
                                        _matchTelemetryText = 'xPass активен: тапните по партнеру или % для умного паса';
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.insights,
                                          size: 16,
                                          color: _showAnalyticsLayer ? Colors.black : const Color(0xFF00E676),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'xPass',
                                          style: TextStyle(
                                            color: _showAnalyticsLayer ? Colors.black : Colors.white,
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

                            // 10d. Кнопка включения карты контроля территории (Voronoi Pitch Control)
                            Positioned(
                              top: 86,
                              left: 10,
                              child: Material(
                                color: _showPitchControlLayer
                                    ? const Color(0xFF00B0FF)
                                    : Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _showPitchControlLayer = !_showPitchControlLayer;
                                      if (_showPitchControlLayer) {
                                        _matchTelemetryText = 'Зоны Вороного: пространственный контроль территории';
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.grid_on,
                                          size: 15,
                                          color: _showPitchControlLayer ? Colors.black : const Color(0xFF00B0FF),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'ЗОНЫ',
                                          style: TextStyle(
                                            color: _showPitchControlLayer ? Colors.black : Colors.white,
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

                            // 10e. Кнопка включения тактического ИИ соперника (Прессинг + Перекрытие xPass)
                            Positioned(
                              top: 124,
                              left: 10,
                              child: Material(
                                color: _enableTacticalAI
                                    ? const Color(0xFFFF5252)
                                    : Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _enableTacticalAI = !_enableTacticalAI;
                                      _matchTelemetryText = _enableTacticalAI
                                          ? 'Тактический ИИ Красных: прессинг и перекрытие xPass включены'
                                          : 'Тактический ИИ Красных отключен (ручной режим)';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.psychology,
                                          size: 16,
                                          color: _enableTacticalAI ? Colors.white : const Color(0xFFFF5252),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'ИИ',
                                          style: TextStyle(
                                            color: Colors.white,
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

                            // 11. Кнопка переключения режима "Тактика / Матч"
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Material(
                                color: _isMatchMode ? const Color(0xFFFFB800) : Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _toggleMatchMode,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isMatchMode ? Icons.sports_soccer : Icons.edit_note,
                                          size: 16,
                                          color: _isMatchMode ? Colors.black : Colors.white,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _isMatchMode ? 'МАТЧ' : 'ТАКТИКА',
                                          style: TextStyle(
                                            color: _isMatchMode ? Colors.black : Colors.white,
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

                            // 12. Кнопка "Удар по воротам" при владении мячом
                            if (_isMatchMode && _ballPossessorIndex != null)
                              Positioned(
                                bottom: 12,
                                left: 24,
                                right: 24,
                                child: Center(
                                  child: Material(
                                    color: const Color(0xFFFFB800),
                                    borderRadius: BorderRadius.circular(20),
                                    elevation: 6,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => _shootBallAtGoal(isOpponent: _ballPossessorIsOpponent),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.sports_soccer, size: 17, color: Colors.black),
                                            const SizedBox(width: 7),
                                            Text(
                                              _ballPossessorIsOpponent ? 'УДАР В СТВОР СИНИХ' : 'УДАР В СТВОР КРАСНЫХ',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11.5,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // 13. Анимированный оверлей "ГОЛ!"
                            if (_showGoalBanner)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.70),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '⚽ ГОООЛ! ⚽',
                                          style: TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFFFB800),
                                            letterSpacing: 2,
                                            shadows: [
                                              Shadow(color: Colors.black, blurRadius: 10),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _goalScorerText,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
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
            if (!isFullscreen) Expanded(
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

  Widget _buildDemoChip(int index, String label) {
    final isSelected = _selectedDemoScenario == index;
    return GestureDetector(
      onTap: () => _applyDemoState(scenarioIndex: index, showCorrect: _demoShowCorrect),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFB800) : Colors.white10,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _getDemoAdviceText() {
    if (_selectedDemoScenario == 0) {
      return !_demoShowCorrect
          ? '❌ ОШИБКА: 4 Синих в куче заблокированы Красными! Фланги брошены, 2 Красных готовы к контратаке.'
          : '✅ КАК НАДО: Синие широко растаскивают оборону Красных! Коридоры открыты под пас.';
    } else if (_selectedDemoScenario == 1) {
      return !_demoShowCorrect
          ? '❌ ОШИБКА: Все Синие убежали вперед! Красный отобрал мяч, выход Красных 2-в-1 на вратаря.'
          : '✅ КАК НАДО: Синий защитник держит центральную ось и накрывает контратаку Красных.';
    } else {
      return !_demoShowCorrect
          ? '❌ ОШИБКА: Красные включили высокий прессинг, Синие прижались спиной к вратарю.'
          : '✅ КАК НАДО: Синие делают рывки по бровкам за спины прессингующих Красных под пас низом.';
    }
  }

  // МЯЧ
  // Взаимная проверка отбора мяча при сближении (для синих и красных)
  // Взаимная проверка отбора мяча при сближении (для синих и красных)
  bool _checkAndHandleTackle(Offset currentPos, {required bool isOpponent}) {
    if (_ballPossessorIndex == null) return false;
    if (!isOpponent && !_showOpponents) return false;
    const double tackleRadius = 0.048;

    final opposingPositions = isOpponent ? _pitchPositions : _opponentPositions;

    for (int j = 0; j < opposingPositions.length; j++) {
      final oppPos = opposingPositions[j];
      if ((currentPos - oppPos).distance < tackleRadius) {
        _ballPosition = Offset(
          (oppPos.dx + 0.052).clamp(0.04, 0.96),
          (oppPos.dy + 0.016).clamp(0.04, 0.96),
        );
        // Мяч полноценно переходит отобравшему игроку
        _ballPossessorIndex = j;
        _ballPossessorIsOpponent = !isOpponent;
        _selectedPlayerForBall = null;
        _activePlayerTrail.clear();
        _blinkController.repeat(reverse: true);

        if (_movingPlayerIndex != null) {
          _movingPlayerIndex = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _moveController.stop();
          });
        }

        HapticFeedback.heavyImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isOpponent
                  ? '⚠️ Отбор мяча! Наш игрок чисто отобрал мяч у соперника.'
                  : '⚠️ Отбор мяча! Соперник чисто отобрал мяч при сближении.'),
              duration: const Duration(milliseconds: 1500),
              backgroundColor: const Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return true;
      }
    }
    return false;
  }

  // Передача мяча между игроками с перехватом защитниками противоположной команды
  void _passBallToPlayer(int targetIndex, {required bool isOpponent}) {
    if (_ballPossessorIndex == null ||
        _ballPossessorIsOpponent != isOpponent ||
        _ballPossessorIndex == targetIndex) {
      return;
    }

    final startPos = _ballPosition;
    final targetCenter = isOpponent ? _opponentPositions[targetIndex] : _pitchPositions[targetIndex];
    final endPos = Offset(
      (targetCenter.dx + 0.052).clamp(0.04, 0.96),
      (targetCenter.dy + 0.016).clamp(0.04, 0.96),
    );

    final v = endPos - startPos;
    final lengthSq = v.dx * v.dx + v.dy * v.dy;

    int? interceptingIndex;
    double minT = 1.0;
    Offset interceptPos = endPos;

    // Защитники противоположной команды
    final defenders = isOpponent ? _pitchPositions : (_showOpponents ? _opponentPositions : const <Offset>[]);

    if (lengthSq > 0.0001) {
      const double interceptionRadius = 0.048;
      for (int j = 0; j < defenders.length; j++) {
        final defPos = defenders[j];
        final w = defPos - startPos;
        final t = (w.dx * v.dx + w.dy * v.dy) / lengthSq;

        if (t > 0.06 && t < 0.94) {
          final projPoint = Offset(startPos.dx + t * v.dx, startPos.dy + t * v.dy);
          final distanceToLine = (defPos - projPoint).distance;

          if (distanceToLine < interceptionRadius && t < minT) {
            minT = t;
            interceptingIndex = j;
            interceptPos = Offset(
              (defPos.dx + 0.052).clamp(0.04, 0.96),
              (defPos.dy + 0.016).clamp(0.04, 0.96),
            );
          }
        }
      }
    }

    final bool isIntercepted = interceptingIndex != null;

    setState(() {
      _ballPassTrail = [startPos, interceptPos];
      // При перехвате адресатом становится сам перехвативший защитник
      _pendingPassTargetIndex = isIntercepted ? interceptingIndex : targetIndex;
      _pendingPassTargetIsOpponent = isIntercepted ? !isOpponent : isOpponent;

      _ballPossessorIndex = null;
      _ballPossessorIsOpponent = false;
      _selectedPlayerForBall = null;
      _movingPlayerIndex = null;
    });

    _blinkController.stop();
    _passController.forward(from: 0.0);

    if (isIntercepted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOpponent
              ? '⚠️ Перехват! Наш защитник перехватил передачу соперника.'
              : '⚠️ Перехват! Защитник соперника заблокировал передачу.'),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      HapticFeedback.lightImpact();
    }
  }
  Widget _buildDraggableBallNode({required BoxConstraints constraints}) {
    if (!_showBall) return const SizedBox.shrink();
    const double ballSize = 24.0;
    final double x = (_ballPosition.dx * constraints.maxWidth) - (ballSize / 2);
    final double y = (_ballPosition.dy * constraints.maxHeight) - (ballSize / 2);

    return Positioned(
      left: x,
      top: y,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // Мяч нельзя двигать самому: игрок подбегает и берет мяч
            if (_selectedPlayerForBall != null) {
              final pIdx = _selectedPlayerForBall!;
              final isOpp = _selectedPlayerForBallIsOpponent;
              final pPos = isOpp ? _opponentPositions[pIdx] : _pitchPositions[pIdx];
              final delta = _ballPosition - pPos;
              final dist = delta.distance;
              final targetPos = dist > 0.04
                  ? Offset(
                      (_ballPosition.dx - (delta.dx / dist) * 0.028).clamp(0.04, 0.96),
                      (_ballPosition.dy - (delta.dy / dist) * 0.022).clamp(0.04, 0.96),
                    )
                  : pPos;
              setState(() {
                _movingPlayerIndex = pIdx;
                _activePlayerTrail = [pPos, targetPos];
                _ballPassTrail.clear();
              });
              _moveController.forward(from: 0.0);
              HapticFeedback.mediumImpact();
            }
          },
          child: Container(
            width: ballSize,
            height: ballSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
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

  // ОБЩИЙ БИЛДЕР ФИШЕК ДЛЯ НАШЕЙ КОМАНДЫ (СИНИЕ) И СОПЕРНИКОВ (КРАСНЫЕ)
  void _startPlayerRun(int index, bool isOpponent, List<Offset> trail) {
    if (trail.length < 2) return;
    final key = _playerKey(index, isOpponent);
    setState(() {
      _runningPlayers[key] = _PlayerRunState(
        index: index,
        isOpponent: isOpponent,
        trail: trail,
        startTime: DateTime.now(),
        durationMs: 1470,
      );
      _movingPlayerIndex = index;
      _activePlayerTrail = trail;
    });

    if (!_moveController.isAnimating) {
      _moveController.repeat();
    }
  }

  
  // ==========================================
  // --- МАТЕМАТИЧЕСКАЯ МОДЕЛЬ ИГРЫ (MATCH ENGINE) ---
  // ==========================================

  // Вынос мяча на 2/3 из-под игрока вперед по направлению атаки (20.7 px)
  // Коэффициент пропорций поля для устранения эллиптического искажения расстояний
  static const double _pitchAspectRatioY = 0.68;

  double _metricDistance(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = (a.dy - b.dy) * _pitchAspectRatioY;
    return math.sqrt(dx * dx + dy * dy);
  }

  // Непрерывная детекция коллизий (расстояние от игрока до отрезка полета мяча за тик)
  Offset _closestPointOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-7) return a;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lenSq).clamp(0.0, 1.0);
    return Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  }

  // 1. Векторное позиционирование мяча: вынос ровно на 2/3 по курсу движения игрока
  Offset _getDribbleBallPosition(Offset playerPos, bool isOpponent) {
    final teamPrefix = isOpponent ? 'opp' : 'own';
    int? idx = _ballPossessorIndex;
    final key = idx != null ? '${teamPrefix}_$idx' : '${teamPrefix}_active';

    final prevPos = _prevPlayerPositions[key];
    Offset heading = _playerHeadings[key] ?? Offset(isOpponent ? -1.0 : 1.0, 0.0);

    if (prevPos != null) {
      final delta = playerPos - prevPos;
      final dist = _metricDistance(playerPos, prevPos);
      if (dist > 0.0025) {
        final normDelta = Offset(delta.dx, delta.dy * _pitchAspectRatioY);
        final len = normDelta.distance;
        if (len > 1e-5) {
          final rawDir = normDelta / len;
          // Плавное сглаживание поворота корпуса игрока (EMA)
          final blended = Offset(
            heading.dx * 0.45 + rawDir.dx * 0.55,
            heading.dy * 0.45 + rawDir.dy * 0.55,
          );
          if (blended.distance > 1e-5) {
            heading = blended / blended.distance;
            _playerHeadings[key] = heading;
          }
        }
      }
    }
    _prevPlayerPositions[key] = playerPos;

    // Радиус фишки 18px + радиус мяча 8px - 1/3 перекрытия (5.3px) = 20.7px выноса вперед
    const double offsetX = 0.050;
    const double offsetY = 0.050 / _pitchAspectRatioY;

    return Offset(
      (playerPos.dx + heading.dx * offsetX).clamp(0.035, 0.965),
      (playerPos.dy + heading.dy * offsetY).clamp(0.04, 0.96),
    );
  }

  // 2. Математическая модель Expected Goals (xG) по стандарту StatsBomb
  double _calculateShotXG(Offset shotPos, {required bool isOpponent}) {
    final double goalX = isOpponent ? 0.04 : 0.96;
    const Offset postTop = Offset(0.0, 0.42);
    const Offset postBottom = Offset(0.0, 0.58);

    final g1 = Offset(goalX, postTop.dy);
    final g2 = Offset(goalX, postBottom.dy);
    final goalCenter = Offset(goalX, 0.50);

    final d1 = _metricDistance(shotPos, g1).clamp(0.02, 2.0);
    final d2 = _metricDistance(shotPos, g2).clamp(0.02, 2.0);
    final distToCenter = _metricDistance(shotPos, goalCenter).clamp(0.02, 2.0);
    const double goalWidthMetric = 0.16 * _pitchAspectRatioY;

    // Теорема косинусов для видимого угла створа ворот
    final cosTheta = ((d1 * d1 + d2 * d2 - goalWidthMetric * goalWidthMetric) / (2 * d1 * d2)).clamp(-1.0, 1.0);
    final theta = math.acos(cosTheta);

    // Коэффициент перекрытия створа вратарем
    double gkBlock = 0.0;
    final gkList = isOpponent ? _pitchPositions : _opponentPositions;
    if (gkList.isNotEmpty) {
      final gkPos = gkList[0];
      final gkDistToLine = (gkPos.dy - 0.50).abs();
      gkBlock = (1.0 - (gkDistToLine / 0.08)).clamp(0.0, 1.0);
    }

    // Логистическая регрессия вероятности гола
    final logit = -2.15 + (3.65 * theta) - (2.15 * distToCenter) - (0.95 * gkBlock);
    final xg = 1.0 / (1.0 + math.exp(-logit));
    return xg.clamp(0.01, 0.97);
  }

  void _toggleMatchMode() {
    setState(() {
      _isMatchMode = !_isMatchMode;
      if (_isMatchMode) {
        _startMatchTimer();
      } else {
        _matchTicker?.cancel();
        _isMatchTimerActive = false;
        _freeBallVelocity = null;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _toggleMatchTimer() {
    setState(() {
      _isMatchTimerActive = !_isMatchTimerActive;
      if (_isMatchTimerActive) {
        _startMatchTimer();
      } else {
        _matchTicker?.cancel();
      }
    });
    HapticFeedback.selectionClick();
  }

  void _resetMatchGame() {
    setState(() {
      _blueScore = 0;
      _redScore = 0;
      _blueXG = 0.0;
      _redXG = 0.0;
      _bluePossessionTicks = 1;
      _redPossessionTicks = 1;
      _matchTelemetryText = 'Матч начался • 1-й тайм';
      _matchSeconds = 300;
      _freeBallVelocity = null;
      _showGoalBanner = false;
      _prevPlayerPositions.clear();
      _playerHeadings.clear();
    });
    _resetFormationPositions();
    _startMatchTimer();
    HapticFeedback.mediumImpact();
  }

  void _startMatchTimer() {
    _matchTicker?.cancel();
    _isMatchTimerActive = true;
    _matchTicker = Timer.periodic(const Duration(milliseconds: 33), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      _matchPhysicsTick();
    });
  }

  void _matchPhysicsTick() {
    if (!_isMatchMode && _freeBallVelocity == null) return;
    if (_passIgnoreTicks > 0) _passIgnoreTicks--;

    bool needsRebuild = false;
    _matchPhysicsCounter++;

    if (_isMatchTimerActive && _matchPhysicsCounter % 30 == 0) {
      if (_matchSeconds > 0) {
        _matchSeconds--;
        needsRebuild = true;
      } else {
        _isMatchTimerActive = false;
        _matchTicker?.cancel();
        _matchTelemetryText = 'Матч окончен • Финальный свисток';
        needsRebuild = true;
      }
    }

    // Учет телеметрии владения мячом
    if (_isMatchTimerActive && !_showGoalBanner) {
      if (_ballPossessorIndex != null) {
        if (_ballPossessorIsOpponent) {
          _redPossessionTicks++;
        } else {
          _bluePossessionTicks++;
        }
      }
    }

    // 3. Баллистика свободного полета мяча и непрерывная детекция коллизий (CCD)
    if (_freeBallVelocity != null) {
      final curVel = _freeBallVelocity!;
      final prevPos = _ballPosition;
      Offset nextPos = Offset(
        (prevPos.dx + curVel.dx).clamp(0.02, 0.98),
        (prevPos.dy + curVel.dy).clamp(0.04, 0.96),
      );

      // Отскок от боковых бровок (аут-стенка в мини-режиме с гашением импульса)
      Offset newVel = curVel * 0.96;
      if (nextPos.dy <= 0.042 || nextPos.dy >= 0.958) {
        newVel = Offset(newVel.dx * 0.85, -newVel.dy * 0.70);
      }

      // Сначала проверяем перехват на отрезке [prevPos -> nextPos]
      final intercepted = _checkBallInterceptionOnFly(prevPos, nextPos);
      if (!intercepted) {
        _ballPosition = nextPos;
        _checkGoalOrSave(prevPos, nextPos, newVel);

        if (_freeBallVelocity != null) {
          if (newVel.distance < 0.0015) {
            _freeBallVelocity = null;
          } else {
            _freeBallVelocity = newVel;
          }
        }
      }
      needsRebuild = true;
    }

    if (_updateTacticalOpponentAI()) {
      needsRebuild = true;
    }
    if (_updateGoalkeepersAI()) {
      needsRebuild = true;
    }
    if (_updateTackleContest()) {
      needsRebuild = true;
    }

    if (needsRebuild && mounted) {
      setState(() {});
    }
  }

  // Расчет вероятности прохождения передачи xPass (%) для физического движка
  int _computePassProbabilityForEngine(
    Offset p0,
    Offset target,
    List<Offset> opponents,
  ) {
    final passDist = _metricDistance(p0, target);
    final ab = target - p0;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-6) return 95;

    double minClearanceRatio = 4.0;
    for (final opp in opponents) {
      final ap = opp - p0;
      final t = (ap.dx * ab.dx + ap.dy * ab.dy) / lenSq;
      if (t < 0.05 || t > 1.05) continue;

      final clampedT = t.clamp(0.0, 1.0);
      final closest = Offset(p0.dx + ab.dx * clampedT, p0.dy + ab.dy * clampedT);
      final perpDist = _metricDistance(opp, closest);
      final coneRadius = 0.026 + 0.14 * (clampedT * passDist);
      final ratio = perpDist / coneRadius;
      if (ratio < minClearanceRatio) {
        minClearanceRatio = ratio;
      }
    }

    final distFactor = math.exp(-0.42 * passDist);
    final openFactor = 1.0 - math.exp(-1.65 * minClearanceRatio * minClearanceRatio);
    return (distFactor * openFactor * 100.0).round().clamp(5, 98);
  }

  // Быстрый пас тапом по партнеру или коридору с учетом вероятности xPass
  void _executeSmartXPass({required int targetIndex, required bool isOpponent}) {
    if (!_showBall) return;
    final teammates = isOpponent ? _opponentPositions : _pitchPositions;
    final opponents = isOpponent ? _pitchPositions : _opponentPositions;
    if (targetIndex < 0 || targetIndex >= teammates.length) return;

    final int? passerIdx = _ballPossessorIndex;
    if (passerIdx == targetIndex && _ballPossessorIsOpponent == isOpponent) return;

    final Offset startPos = passerIdx != null && passerIdx < teammates.length
        ? teammates[passerIdx]
        : _ballPosition;

    // Если партнер бежит по треку — делаем пас на ход (упреждение)
    Offset aimTarget = teammates[targetIndex];
    final runnerKey = '${isOpponent ? "opp" : "own"}_$targetIndex';
    if (_runningPlayers.containsKey(runnerKey)) {
      final runner = _runningPlayers[runnerKey]!;
      if (runner.trail.length >= 2) {
        final nextStep = runner.trail.last - aimTarget;
        if (nextStep.distance > 0.02) {
          final leadDir = nextStep / nextStep.distance;
          aimTarget = Offset(
            (aimTarget.dx + leadDir.dx * 0.045).clamp(0.05, 0.95),
            (aimTarget.dy + leadDir.dy * 0.045).clamp(0.05, 0.95),
          );
        }
      }
    }

    final int xPassPct = _computePassProbabilityForEngine(startPos, aimTarget, opponents);
    final Offset rawVec = aimTarget - _ballPosition;
    final double euclidDist = rawVec.distance;
    if (euclidDist < 0.01) return;

    // Проверка успешности паса по модели xPass
    final rng = math.Random();
    final double roll = rng.nextDouble() * 100.0;
    final bool isCleanPass = roll <= xPassPct;

    double baseAngle = math.atan2(rawVec.dy, rawVec.dx);
    if (isCleanPass) {
      // Минимальная погрешность при успешном прохождении коридора
      baseAngle += (rng.nextDouble() - 0.5) * 0.024;
    } else {
      // Срыв траектории под прессингом (чем ниже xPass, тем сильнее отклонение)
      final double pressureFactor = (100 - xPassPct) / 100.0;
      final double sign = rng.nextBool() ? 1.0 : -1.0;
      baseAngle += sign * (0.055 + 0.20 * pressureFactor);
    }

    final Offset launchDir = Offset(math.cos(baseAngle), math.sin(baseAngle));
    // Калибровка начальной скорости под трение 0.96 за тик (S = V0 / 0.04)
    final double speed = (0.040 * euclidDist + 0.0135).clamp(0.022, 0.052);

    final String passerKey = '${isOpponent ? "opp" : "own"}_${passerIdx ?? 0}';
    _playerHeadings[passerKey] = launchDir;

    if (_passController.isAnimating) {
      _passController.stop();
    }

    HapticFeedback.lightImpact();
    setState(() {
      _selectedPlayerForBall = null;
      _lastPasserIndex = passerIdx;
      _lastPasserIsOpponent = isOpponent;
      _passIgnoreTicks = 7;
      _lastShotByOpponent = isOpponent;
      _ballPossessorIndex = null;
      _freeBallVelocity = launchDir * speed;

      final teamName = isOpponent ? 'Красные' : 'Синие';
      if (isCleanPass) {
        _matchTelemetryText =
            'Пас $teamName (#${(passerIdx ?? 0) + 1} ➔ #${targetIndex + 1}) • xPass: $xPassPct% (точно в темп)';
      } else {
        _matchTelemetryText =
            'Риск перехвата! Пас $teamName (#${(passerIdx ?? 0) + 1} ➔ #${targetIndex + 1}) • xPass: $xPassPct%';
      }
    });

    // Запускаем физический тикер, если пас отдан в тактическом режиме с включенным xPass
    if (_matchTicker == null || !_matchTicker!.isActive) {
      _matchTicker = Timer.periodic(const Duration(milliseconds: 33), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        _matchPhysicsTick();
      });
    }
  }

  // Обработка быстрого тапа по партнеру или по плашке процента xPass на поле
  void _handlePitchQuickTap(Offset localPos, Size pitchSize) {
    if (!_showBall) return;
    if (!_isMatchMode && !_showAnalyticsLayer) return;

    // Игнорируем клики по верхним и нижним HUD-кнопкам поля
    if (localPos.dy < 168 && (localPos.dx < 115 || localPos.dx > pitchSize.width - 65)) {
      return;
    }
    if (_isMatchMode && _ballPossessorIndex != null && localPos.dy > pitchSize.height - 52) {
      return;
    }

    final Offset tapNorm = Offset(
      (localPos.dx / pitchSize.width).clamp(0.0, 1.0),
      (localPos.dy / pitchSize.height).clamp(0.0, 1.0),
    );

    int? carrierIdx = _ballPossessorIndex;
    bool isOpp = _ballPossessorIsOpponent;

    // Если мяч свободен, но лежит рядом с игроком — считаем его распасовщиком
    if (carrierIdx == null) {
      double minDist = 0.085;
      for (int i = 0; i < _pitchPositions.length; i++) {
        final d = _metricDistance(_pitchPositions[i], _ballPosition);
        if (d < minDist) {
          minDist = d;
          carrierIdx = i;
          isOpp = false;
        }
      }
      for (int i = 0; i < _opponentPositions.length; i++) {
        final d = _metricDistance(_opponentPositions[i], _ballPosition);
        if (d < minDist) {
          minDist = d;
          carrierIdx = i;
          isOpp = true;
        }
      }
    }

    if (carrierIdx == null) return;
    final teammates = isOpp ? _opponentPositions : _pitchPositions;
    if (carrierIdx >= teammates.length) return;
    final Offset p0 = teammates[carrierIdx];

    int? chosenTarget;
    double bestHitDist = 0.056;

    for (int i = 0; i < teammates.length; i++) {
      if (i == carrierIdx) continue;
      final Offset target = teammates[i];

      // 1. Проверка тапа прямо по фишке партнера
      final double distToPlayer = _metricDistance(tapNorm, target);
      if (distToPlayer < bestHitDist) {
        bestHitDist = distToPlayer;
        chosenTarget = i;
      }

      // 2. Проверка тапа по бейджу xPass% в середине коридора паса
      if (_showAnalyticsLayer) {
        final Offset midBadge = Offset(
          p0.dx * 0.45 + target.dx * 0.55,
          p0.dy * 0.45 + target.dy * 0.55,
        );
        final double distToBadge = _metricDistance(tapNorm, midBadge);
        if (distToBadge < bestHitDist) {
          bestHitDist = distToBadge;
          chosenTarget = i;
        }
      }
    }

    if (chosenTarget != null) {
      final int targetIdx = chosenTarget;
      final bool teamFlag = isOpp;
      Future.microtask(() {
        if (mounted) {
          _executeSmartXPass(targetIndex: targetIdx, isOpponent: teamFlag);
        }
      });
    }
  }

  void _shootBallAtGoal({required bool isOpponent}) {
    if (!_showBall) return;
    HapticFeedback.mediumImpact();

    final double targetX = isOpponent ? 0.035 : 0.965;
    // Целимся в углы створа ворот (с небольшим разбросом точности)
    final rng = math.Random();
    final bool aimTopCorner = rng.nextBool();
    final double baseAimY = aimTopCorner ? 0.445 : 0.555;
    final double spread = (rng.nextDouble() - 0.5) * 0.055;
    final double targetY = (baseAimY + spread).clamp(0.39, 0.61);
    final target = Offset(targetX, targetY);

    final shotXG = _calculateShotXG(_ballPosition, isOpponent: isOpponent);

    final dir = target - _ballPosition;
    if (dir.distance > 0.001) {
      final norm = dir / dir.distance;
      final key = isOpponent ? 'opp_${_ballPossessorIndex ?? 0}' : 'own_${_ballPossessorIndex ?? 0}';
      _playerHeadings[key] = norm;

      setState(() {
        if (isOpponent) {
          _redXG += shotXG;
          _matchTelemetryText = 'Удар Красных • xG момента: ${shotXG.toStringAsFixed(2)}';
        } else {
          _blueXG += shotXG;
          _matchTelemetryText = 'Удар Синих • xG момента: ${shotXG.toStringAsFixed(2)}';
        }
        _lastShotByOpponent = isOpponent;
        _ballPossessorIndex = null;
        _freeBallVelocity = norm * 0.046;
      });
    }
  }

  void _checkGoalOrSave(Offset prevPos, Offset ballPos, Offset velocity) {
    if (_showGoalBanner) return;

    // 1. Правые ворота (Красные защищают, Синие атакуют)
    if (ballPos.dx >= 0.945) {
      // Проверка попадания в штангу (каркас ворот: 0.405..0.422 и 0.578..0.595)
      if ((ballPos.dy >= 0.402 && ballPos.dy < 0.420) || (ballPos.dy > 0.580 && ballPos.dy <= 0.598)) {
        HapticFeedback.heavyImpact();
        _freeBallVelocity = Offset(-velocity.dx.abs() * 0.55, (ballPos.dy < 0.5 ? -0.015 : 0.015));
        _matchTelemetryText = 'ШТАНГА! Каркас спасает ворота Красных!';
        return;
      }

      // Створ ворот [0.420 .. 0.580]
      if (ballPos.dy >= 0.420 && ballPos.dy <= 0.580) {
        final gkPos = _opponentPositions.isNotEmpty ? _opponentPositions[0] : const Offset(0.92, 0.50);
        final distToGk = _metricDistance(gkPos, ballPos);

        if (distToGk < 0.032) {
          // Сейв вратаря Красных (ловля намертво или отбивание перед собой при мощном ударе)
          HapticFeedback.lightImpact();
          if (velocity.distance > 0.038 && math.Random().nextDouble() < 0.35) {
            _freeBallVelocity = Offset(-0.024, (math.Random().nextDouble() - 0.5) * 0.03);
            _matchTelemetryText = 'СЕЙВ! Вратарь Красных отбивает мяч в поле!';
          } else {
            _freeBallVelocity = null;
            if (_opponentPositions.isNotEmpty) {
              _ballPossessorIndex = 0;
              _ballPossessorIsOpponent = true;
              _playerHeadings['opp_0'] = const Offset(-1.0, 0.0);
              _ballPosition = _getDribbleBallPosition(gkPos, true);
              _matchTelemetryText = 'Вратарь Красных намертво фиксирует мяч';
            }
          }
        } else if (ballPos.dx >= 0.955) {
          _handleGoal(scoredByBlue: true);
        }
        return;
      } else if (ballPos.dx >= 0.965) {
        // Уход за лицевую линию (удар от ворот)
        _freeBallVelocity = null;
        if (_opponentPositions.isNotEmpty) {
          _ballPossessorIndex = 0;
          _ballPossessorIsOpponent = true;
          _ballPosition = _getDribbleBallPosition(_opponentPositions[0], true);
          _matchTelemetryText = 'Мимо створа • Удар от ворот Красных';
        }
      }
    }

    // 2. Левые ворота (Синие защищают, Красные атакуют)
    if (ballPos.dx <= 0.055) {
      if ((ballPos.dy >= 0.402 && ballPos.dy < 0.420) || (ballPos.dy > 0.580 && ballPos.dy <= 0.598)) {
        HapticFeedback.heavyImpact();
        _freeBallVelocity = Offset(velocity.dx.abs() * 0.55, (ballPos.dy < 0.5 ? -0.015 : 0.015));
        _matchTelemetryText = 'ШТАНГА! Каркас спасает ворота Синих!';
        return;
      }

      if (ballPos.dy >= 0.420 && ballPos.dy <= 0.580) {
        final gkPos = _pitchPositions.isNotEmpty ? _pitchPositions[0] : const Offset(0.08, 0.50);
        final distToGk = _metricDistance(gkPos, ballPos);

        if (distToGk < 0.032) {
          HapticFeedback.lightImpact();
          if (velocity.distance > 0.038 && math.Random().nextDouble() < 0.35) {
            _freeBallVelocity = Offset(0.024, (math.Random().nextDouble() - 0.5) * 0.03);
            _matchTelemetryText = 'СЕЙВ! Вратарь Синих парирует сложный удар!';
          } else {
            _freeBallVelocity = null;
            if (_pitchPositions.isNotEmpty) {
              _ballPossessorIndex = 0;
              _ballPossessorIsOpponent = false;
              _playerHeadings['own_0'] = const Offset(1.0, 0.0);
              _ballPosition = _getDribbleBallPosition(gkPos, false);
              _matchTelemetryText = 'Вратарь Синих забирает мяч в руки';
            }
          }
        } else if (ballPos.dx <= 0.045) {
          _handleGoal(scoredByBlue: false);
        }
        return;
      } else if (ballPos.dx <= 0.035) {
        _freeBallVelocity = null;
        if (_pitchPositions.isNotEmpty) {
          _ballPossessorIndex = 0;
          _ballPossessorIsOpponent = false;
          _ballPosition = _getDribbleBallPosition(_pitchPositions[0], false);
          _matchTelemetryText = 'Мимо створа • Удар от ворот Синих';
        }
      }
    }
  }

  void _handleGoal({required bool scoredByBlue}) {
    _freeBallVelocity = null;
    HapticFeedback.heavyImpact();

    setState(() {
      if (scoredByBlue) {
        _blueScore++;
        _goalScorerText = 'ГОЛ! СИНИЕ ЗАБИЛИ! (xG: ${_blueXG.toStringAsFixed(2)})';
        _matchTelemetryText = 'ГОЛ СИНИХ! Счет становится $_blueScore : $_redScore';
      } else {
        _redScore++;
        _goalScorerText = 'ГОЛ! КРАСНЫЕ ЗАБИЛИ! (xG: ${_redXG.toStringAsFixed(2)})';
        _matchTelemetryText = 'ГОЛ КРАСНЫХ! Счет становится $_blueScore : $_redScore';
      }
      _showGoalBanner = true;
      _ballPossessorIndex = null;
    });

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      _resetToKickoff();
      setState(() {
        _showGoalBanner = false;
      });
    });
  }

  void _resetToKickoff() {
    _resetFormationPositions();
    setState(() {
      _ballPosition = const Offset(0.50, 0.50);
      _ballPossessorIndex = null;
      _freeBallVelocity = null;
    });
  }

  // Тактический ИИ полевых игроков соперника: прессинг носителя мяча, перекрытие коридоров xPass и контратака
  bool _updateTacticalOpponentAI() {
    if (!_isMatchMode || !_enableTacticalAI || !_isMatchTimerActive || _showGoalBanner || _isDemoMode) {
      return false;
    }
    if (_opponentPositions.length <= 1) return false;

    bool changed = false;
    _aiDecisionTicks++;

    // --- СЦЕНАРИЙ А: МЯЧ У КРАСНЫХ (АТАКА / КОНТРАТАКА ИИ) ---
    if (_ballPossessorIndex != null && _ballPossessorIsOpponent) {
      final int carrierIdx = _ballPossessorIndex!;
      if (carrierIdx >= 0 && carrierIdx < _opponentPositions.length) {
        final Offset carrierPos = _opponentPositions[carrierIdx];

        // Принятие тактического решения каждые 16 тиков (~0.52 сек)
        if (_aiDecisionTicks >= 16) {
          _aiDecisionTicks = 0;

          // 1. Если вратарь Красных (j == 0) держит мяч — пас открытому полевому партнеру
          if (carrierIdx == 0) {
            int bestTarget = -1;
            int bestProb = -1;
            for (int j = 1; j < _opponentPositions.length; j++) {
              final int prob = _computePassProbabilityForEngine(
                carrierPos,
                _opponentPositions[j],
                _pitchPositions,
              );
              if (prob > bestProb) {
                bestProb = prob;
                bestTarget = j;
              }
            }
            if (bestTarget != -1) {
              Future.microtask(() {
                if (mounted) _executeSmartXPass(targetIndex: bestTarget, isOpponent: true);
              });
              return true;
            }
          } else {
            // 2. Проверка ударной позиции (xG >= 0.20 или близость к воротам Синих)
            final double currentXG = _calculateShotXG(carrierPos, isOpponent: true);
            if (carrierPos.dx < 0.27 || currentXG >= 0.20) {
              Future.microtask(() {
                if (mounted) _shootBallAtGoal(isOpponent: true);
              });
              return true;
            }

            // 3. Поиск обостряющего паса вперед с высоким xPass (%)
            int bestPassTarget = -1;
            double bestPassScore = -999.0;
            for (int j = 1; j < _opponentPositions.length; j++) {
              if (j == carrierIdx) continue;
              final Offset matePos = _opponentPositions[j];
              final int prob = _computePassProbabilityForEngine(
                carrierPos,
                matePos,
                _pitchPositions,
              );
              final double forwardGain = carrierPos.dx - matePos.dx;
              // Комбинированная оценка: проходимость коридора + продвижение к воротам Синих
              final double score = prob + (forwardGain * 130.0);
              if (prob >= 64 && forwardGain > 0.04 && score > bestPassScore) {
                bestPassScore = score;
                bestPassTarget = j;
              }
            }

            if (bestPassTarget != -1) {
              final int targetIdx = bestPassTarget;
              Future.microtask(() {
                if (mounted) _executeSmartXPass(targetIndex: targetIdx, isOpponent: true);
              });
              return true;
            }
          }
        }

        // 4. Дриблинг носителя мяча к воротам Синих (x = 0.04, y = 0.50) с уходом от защитника
        if (carrierIdx > 0 && !_runningPlayers.containsKey('opp_$carrierIdx')) {
          Offset goalDir = const Offset(0.06, 0.50) - carrierPos;
          if (goalDir.distance > 0.001) {
            goalDir = goalDir / goalDir.distance;
          }
          Offset evadeVec = Offset.zero;
          for (final bp in _pitchPositions) {
            final double d = _metricDistance(carrierPos, bp);
            if (d < 0.09 && d > 1e-4) {
              final Offset away = carrierPos - bp;
              evadeVec += (away / away.distance) * ((0.09 - d) * 6.0);
            }
          }
          Offset moveDir = goalDir + evadeVec * 0.65;
          if (moveDir.distance > 1e-4) {
            moveDir = moveDir / moveDir.distance;
            final Offset nextPos = Offset(
              (carrierPos.dx + moveDir.dx * 0.0038).clamp(0.07, 0.93),
              (carrierPos.dy + moveDir.dy * 0.0046).clamp(0.07, 0.93),
            );
            _opponentPositions[carrierIdx] = nextPos;
            _ballPosition = _getDribbleBallPosition(nextPos, true);
            changed = true;
          }
        }

        // 5. Открывание остальных полевых игроков Красных в свободные зоны атаки
        for (int j = 1; j < _opponentPositions.length; j++) {
          if (j == carrierIdx || _runningPlayers.containsKey('opp_$j')) continue;
          final Offset cur = _opponentPositions[j];
          final double laneY = (0.18 + ((j - 1) / math.max(1, _opponentPositions.length - 2)) * 0.64).clamp(0.12, 0.88);
          final double targetX = (carrierPos.dx - 0.14 + (j.isEven ? -0.04 : 0.04)).clamp(0.14, 0.78);
          final Offset supportTarget = Offset(targetX, laneY);
          final Offset delta = supportTarget - cur;
          if (delta.distance > 0.012) {
            final Offset dir = delta / delta.distance;
            _opponentPositions[j] = Offset(
              (cur.dx + dir.dx * 0.0034).clamp(0.08, 0.92),
              (cur.dy + dir.dy * 0.0038).clamp(0.07, 0.93),
            );
            changed = true;
          }
        }
      }
      return changed;
    }

    // --- СЦЕНАРИЙ Б: МЯЧ У СИНИХ ИЛИ СВОБОДЕН (ПРЕССИНГ + ПЕРЕКРЫТИЕ КОРИДОРОВ xPass) ---
    final Offset ballRef = (_ballPossessorIndex != null && !_ballPossessorIsOpponent && _ballPossessorIndex! < _pitchPositions.length)
        ? _pitchPositions[_ballPossessorIndex!]
        : _ballPosition;

    // 1. Определяем ближайшего полевого игрока Красных для активного прессинга (Primary Presser)
    int presserIdx = -1;
    double minPressDist = 999.0;
    for (int j = 1; j < _opponentPositions.length; j++) {
      if (_runningPlayers.containsKey('opp_$j')) continue;
      final double d = _metricDistance(_opponentPositions[j], ballRef);
      if (d < minPressDist) {
        minPressDist = d;
        presserIdx = j;
      }
    }

    // Движение прессингующего игрока в точку Goal-Side (между мячом и воротами Красных)
    if (presserIdx != -1) {
      final Offset cur = _opponentPositions[presserIdx];
      const Offset redGoal = Offset(0.96, 0.50);
      Offset toGoal = redGoal - ballRef;
      if (toGoal.distance > 1e-4) {
        toGoal = toGoal / toGoal.distance;
      }
      // Если мяч ничейный — бежим прямо на мяч; если у игрока Синих — сближаемся вплотную для отбора
      final Offset pressTarget = (_ballPossessorIndex == null)
          ? ballRef
          : Offset(
              (ballRef.dx + toGoal.dx * 0.014).clamp(0.05, 0.94),
              (ballRef.dy + toGoal.dy * 0.014).clamp(0.06, 0.94),
            );
      final Offset delta = pressTarget - cur;
      if (delta.distance > 0.004) {
        final Offset dir = delta / delta.distance;
        final double step = math.min(0.0046, delta.distance);
        _opponentPositions[presserIdx] = Offset(
          (cur.dx + dir.dx * step).clamp(0.06, 0.93),
          (cur.dy + dir.dy * step).clamp(0.06, 0.94),
        );
        _playerHeadings['opp_$presserIdx'] = dir;
        changed = true;
      }
    }

    // 2. Формируем список узлов перехвата (Cover Shadow Nodes) на коридорах паса Синих
    final List<Offset> coverNodes = [];
    final int? blueCarrier = (!_ballPossessorIsOpponent) ? _ballPossessorIndex : null;

    for (int i = 0; i < _pitchPositions.length; i++) {
      if (i == blueCarrier) continue;
      final Offset receiver = _pitchPositions[i];
      // Игнорируем глубокого вратаря Синих, если мяч далеко впереди
      if (i == 0 && ballRef.dx > 0.38) continue;

      // Точка на 52% длины коридора паса — максимум перекрытия тени xPass
      final Offset shadowNode = Offset(
        ballRef.dx + (receiver.dx - ballRef.dx) * 0.52,
        ballRef.dy + (receiver.dy - ballRef.dy) * 0.52,
      );
      coverNodes.add(shadowNode);
    }

    // Сортируем коридоры по опасности (чем ближе к воротам Красных x = 0.96, тем приоритетнее)
    coverNodes.sort((a, b) => b.dx.compareTo(a.dx));
    final Set<int> assignedNodes = {};

    // 3. Распределяем остальных полевых игроков Красных по коридорам xPass
    for (int j = 1; j < _opponentPositions.length; j++) {
      if (j == presserIdx || _runningPlayers.containsKey('opp_$j')) continue;
      final Offset cur = _opponentPositions[j];

      int bestNodeIdx = -1;
      double bestNodeCost = 999.0;
      for (int n = 0; n < coverNodes.length; n++) {
        if (assignedNodes.contains(n)) continue;
        final double d = _metricDistance(cur, coverNodes[n]);
        // Учитываем близость защитника к линии паса и опасность зоны
        final double cost = d - (coverNodes[n].dx * 0.12);
        if (cost < bestNodeCost) {
          bestNodeCost = cost;
          bestNodeIdx = n;
        }
      }

      // Базовый зональный якорь игрока для сохранения структуры обороны
      final double baseZonalX = (ballRef.dx + 0.22).clamp(0.42, 0.84);
      final double baseZonalY = (0.16 + ((j - 1) / math.max(1, _opponentPositions.length - 2)) * 0.68).clamp(0.12, 0.88);
      final Offset zonalAnchor = Offset(baseZonalX, baseZonalY);

      Offset targetPos = zonalAnchor;
      if (bestNodeIdx != -1) {
        assignedNodes.add(bestNodeIdx);
        final Offset node = coverNodes[bestNodeIdx];
        // Смешиваем узел перекрытия коридора паса (78%) и зональную компактность (22%)
        targetPos = Offset(
          node.dx * 0.78 + zonalAnchor.dx * 0.22,
          node.dy * 0.78 + zonalAnchor.dy * 0.22,
        );
      }

      // Вектор взаимного отталкивания защитников (Boids Separation), чтобы не слипались в одну точку
      Offset separation = Offset.zero;
      for (int k = 1; k < _opponentPositions.length; k++) {
        if (k == j) continue;
        final double distOther = _metricDistance(cur, _opponentPositions[k]);
        if (distOther < 0.075 && distOther > 1e-4) {
          final Offset diff = cur - _opponentPositions[k];
          separation += (diff / diff.distance) * ((0.075 - distOther) * 0.45);
        }
      }

      targetPos = Offset(
        (targetPos.dx + separation.dx).clamp(0.08, 0.91),
        (targetPos.dy + separation.dy).clamp(0.07, 0.93),
      );

      final Offset moveVec = targetPos - cur;
      if (moveVec.distance > 0.004) {
        final Offset dir = moveVec / moveVec.distance;
        final double step = math.min(0.0036, moveVec.distance);
        _opponentPositions[j] = Offset(
          (cur.dx + dir.dx * step).clamp(0.08, 0.91),
          (cur.dy + dir.dy * step).clamp(0.07, 0.93),
        );
        _playerHeadings['opp_$j'] = dir;
        changed = true;
      }
    }

    return changed;
  }

  bool _updateGoalkeepersAI() {
    if (!_isMatchMode || _isDemoMode) return false;
    bool changed = false;

    // Не перезаписываем позицию вратаря Синих, если игрок ведет его вручную или он бежит по треку
    if (_pitchPositions.isNotEmpty && !_runningPlayers.containsKey('own_0')) {
      final curGk = _pitchPositions[0];
      final targetY = _ballPosition.dy.clamp(0.435, 0.565);
      if ((curGk.dy - targetY).abs() > 0.0015) {
        final newY = curGk.dy + (targetY - curGk.dy) * 0.16;
        _pitchPositions[0] = Offset(0.075, newY);
        changed = true;
      }
    }

    // Аналогично для вратаря Красных
    if (_opponentPositions.isNotEmpty && !_runningPlayers.containsKey('opp_0')) {
      final curGk = _opponentPositions[0];
      final targetY = _ballPosition.dy.clamp(0.435, 0.565);
      if ((curGk.dy - targetY).abs() > 0.0015) {
        final newY = curGk.dy + (targetY - curGk.dy) * 0.16;
        _opponentPositions[0] = Offset(0.925, newY);
        changed = true;
      }
    }

    return changed;
  }

  bool _updateTackleContest() {
    if (!_isMatchMode || _ballPossessorIndex == null) return false;

    final now = DateTime.now();
    if (now.difference(_lastTackleTime).inMilliseconds < 850) return false;

    final isOpp = _ballPossessorIsOpponent;
    final carrierIdx = _ballPossessorIndex!;
    final carrierPositions = isOpp ? _opponentPositions : _pitchPositions;
    final defenderPositions = isOpp ? _pitchPositions : _opponentPositions;

    if (carrierIdx >= carrierPositions.length) return false;
    final carrierPos = carrierPositions[carrierIdx];
    final carrierKey = isOpp ? 'opp_$carrierIdx' : 'own_$carrierIdx';
    final carrierHeading = _playerHeadings[carrierKey] ?? Offset(isOpp ? -1.0 : 1.0, 0.0);

    for (int j = 0; j < defenderPositions.length; j++) {
      final defPos = defenderPositions[j];
      final dist = _metricDistance(carrierPos, defPos);

      if (dist < 0.040) {
        _lastTackleTime = now;
        // Векторный анализ угла атаки защитника (встречный отбор спереди эффективнее отбора со спины)
        final toDefender = defPos - carrierPos;
        final dot = toDefender.dx * carrierHeading.dx + toDefender.dy * carrierHeading.dy;
        final double tackleSuccessProb = dot > 0 ? 0.72 : 0.38;

        final roll = math.Random().nextDouble();
        if (roll < tackleSuccessProb) {
          HapticFeedback.mediumImpact();
          if (roll < tackleSuccessProb * 0.68) {
            _ballPossessorIndex = j;
            _ballPossessorIsOpponent = !isOpp;
            final defKey = !isOpp ? 'opp_$j' : 'own_$j';
            _playerHeadings[defKey] = Offset(!isOpp ? -1.0 : 1.0, 0.0);
            _ballPosition = _getDribbleBallPosition(defPos, !isOpp);
            _matchTelemetryText = !isOpp
                ? 'Чистый отбор Красных (#${j + 1})!'
                : 'Чистый отбор Синих (#${j + 1})!';
          } else {
            final looseDir = Offset(
              (math.Random().nextDouble() - 0.5) * 0.036,
              (math.Random().nextDouble() - 0.5) * 0.036,
            );
            _ballPossessorIndex = null;
            _freeBallVelocity = looseDir;
            _matchTelemetryText = 'Борьба за мяч • Рикошет в свободную зону!';
          }
          return true;
        }
        break;
      }
    }
    return false;
  }

  bool _checkBallInterceptionOnFly(Offset prevBallPos, Offset nextBallPos) {
    if (_ballPossessorIndex != null) return false;

    for (int i = 0; i < _pitchPositions.length; i++) {
      // Вратарь обрабатывается в _checkGoalOrSave при ударе по его воротам
      if (_passIgnoreTicks > 0 && !_lastPasserIsOpponent && i == _lastPasserIndex) continue;
      if (_passIgnoreTicks > 0 && !_lastPasserIsOpponent && i == _lastPasserIndex) continue;
      if (_passIgnoreTicks > 0 && !_lastPasserIsOpponent && i == _lastPasserIndex) continue;
      if (i == 0 && _lastShotByOpponent && nextBallPos.dx < 0.14) continue;
      final p = _pitchPositions[i];
      final closest = _closestPointOnSegment(p, prevBallPos, nextBallPos);
      if (_metricDistance(p, closest) < 0.033) {
        _ballPossessorIndex = i;
        _ballPossessorIsOpponent = false;
        _freeBallVelocity = null;
        _ballPosition = _getDribbleBallPosition(p, false);
        _matchTelemetryText = 'Перехват / прием мяча: Синие (#${i + 1})';
        HapticFeedback.selectionClick();
        return true;
      }
    }

    for (int i = 0; i < _opponentPositions.length; i++) {
      if (_passIgnoreTicks > 0 && _lastPasserIsOpponent && i == _lastPasserIndex) continue;
      if (_passIgnoreTicks > 0 && _lastPasserIsOpponent && i == _lastPasserIndex) continue;
      if (_passIgnoreTicks > 0 && _lastPasserIsOpponent && i == _lastPasserIndex) continue;
      if (i == 0 && !_lastShotByOpponent && nextBallPos.dx > 0.86) continue;
      final p = _opponentPositions[i];
      final closest = _closestPointOnSegment(p, prevBallPos, nextBallPos);
      if (_metricDistance(p, closest) < 0.033) {
        _ballPossessorIndex = i;
        _ballPossessorIsOpponent = true;
        _freeBallVelocity = null;
        _ballPosition = _getDribbleBallPosition(p, true);
        _matchTelemetryText = 'Перехват / прием мяча: Красные (#${i + 1})';
        HapticFeedback.selectionClick();
        return true;
      }
    }

    return false;
  }

  Widget _buildMatchScoreboard() {
    final minutes = (_matchSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_matchSeconds % 60).toString().padLeft(2, '0');
    final totalTicks = (_bluePossessionTicks + _redPossessionTicks).clamp(1, 999999);
    final bluePossPct = ((_bluePossessionTicks * 100) / totalTicks).round().clamp(1, 99);
    final redPossPct = 100 - bluePossPct;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2235), Color(0xFF10131E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E88E5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'СИНИЕ',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      Text(
                        'xG ${_blueXG.toStringAsFixed(2)} • $bluePossPct%',
                        style: const TextStyle(color: Colors.white60, fontSize: 9.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  '$_blueScore : $_redScore',
                  style: const TextStyle(
                    color: Color(0xFFFFB800),
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'КРАСНЫЕ',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      Text(
                        '$redPossPct% • xG ${_redXG.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white60, fontSize: 9.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0E17),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$minutes:$seconds',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: _toggleMatchTimer,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isMatchTimerActive ? const Color(0xFFFFB800) : Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _isMatchTimerActive ? Icons.pause : Icons.play_arrow,
                        size: 15,
                        color: _isMatchTimerActive ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: _resetMatchGame,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.refresh, size: 15, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Полоса владения мячом и живая аналитическая строка (как в Veo / Metrica)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 3,
              child: Row(
                children: [
                  Expanded(
                    flex: bluePossPct,
                    child: Container(color: const Color(0xFF1E88E5)),
                  ),
                  Expanded(
                    flex: redPossPct,
                    child: Container(color: const Color(0xFFE53935)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _matchTelemetryText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFB800),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTeamPlayerNodes({
    required BoxConstraints constraints,
    required List<Offset> positions,
    required bool isOpponent,
    required List<Map<String, dynamic>> starters,
  }) {
    const double nodeSize = 36.0;

    return List.generate(positions.length, (i) {
      final pos = positions[i];
      final player = (!isOpponent && i < starters.length) ? starters[i] : null;
      final name = isOpponent
          ? 'Соперник'
          : (player != null ? '${player['last_name'] ?? 'Игрок'}' : 'Слот');
      final numberText = isOpponent ? 'К${i + 1}' : '#${player?['jersey_number'] ?? (i + 1)}';

      final double x = (pos.dx * constraints.maxWidth - (nodeSize / 2)).clamp(4.0, constraints.maxWidth - nodeSize - 4.0);
      final double y = (pos.dy * constraints.maxHeight - (nodeSize / 2)).clamp(4.0, constraints.maxHeight - nodeSize - 4.0);

      final String pKey = _playerKey(i, isOpponent);
      final bool isTouching = _activeTouchPlayerKeys.contains(pKey);
      final bool isMoving = _runningPlayers.containsKey(pKey);
      final bool isActive = isTouching || isMoving;
      final bool isSelected = _selectedPlayerForBall == i && _selectedPlayerForBallIsOpponent == isOpponent;
      final bool hasBall = _ballPossessorIndex == i && _ballPossessorIsOpponent == isOpponent;

      return Positioned(
        left: x,
        top: y,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_ballPossessorIndex != null && _ballPossessorIsOpponent == isOpponent) {
                if (_ballPossessorIndex != i) {
                  _passBallToPlayer(i, isOpponent: isOpponent);
                }
              } else {
                setState(() {
                  _selectedPlayerForBall = i;
                  _selectedPlayerForBallIsOpponent = isOpponent;
                });
                HapticFeedback.selectionClick();
              }
            },
            onPanDown: (_) {
              HapticFeedback.mediumImpact();
              _fadeController.stop();
              setState(() {
                _activeTouchPlayerKeys.add(pKey);
                _playerTrails[pKey] = [positions[i]];
                _runningPlayers.remove(pKey);
                _activePlayerTrail = _playerTrails[pKey]!;
              });
              _blinkController.repeat(reverse: true);
            },
            onPanUpdate: (details) {
              final trail = _playerTrails[pKey];
              final currentPoint = (trail != null && trail.isNotEmpty)
                  ? trail.last
                  : positions[i];

              final double nextDx = (currentPoint.dx + details.delta.dx / constraints.maxWidth).clamp(0.04, 0.96);
              final double nextDy = (currentPoint.dy + details.delta.dy / constraints.maxHeight).clamp(0.04, 0.96);
              final nextPos = Offset(nextDx, nextDy);

              if (_ballPossessorIndex == i && _ballPossessorIsOpponent == isOpponent) {
                _ballPosition = _getDribbleBallPosition(nextPos, isOpponent);
              } else if (_showBall && _ballPossessorIndex == null && (nextPos - _ballPosition).distance < 0.045) {
                _ballPossessorIndex = i;
                _ballPossessorIsOpponent = isOpponent;
                _ballPosition = _getDribbleBallPosition(nextPos, isOpponent);
                _blinkController.repeat(reverse: true);
              }

              setState(() {
                if (trail == null || trail.isEmpty) {
                  _playerTrails[pKey] = [positions[i], nextPos];
                } else {
                  if ((trail.last - nextPos).distance > 0.008) {
                    trail.add(nextPos);
                  }
                }
                _activePlayerTrail = _playerTrails[pKey] ?? [];
              });
            },
            onPanEnd: (_) {
              final trail = _playerTrails[pKey];
              setState(() {
                _activeTouchPlayerKeys.remove(pKey);
              });

              if (trail == null || trail.length < 2) {
                setState(() {
                  _playerTrails.remove(pKey);
                });
                if (_activeTouchPlayerKeys.isEmpty && _runningPlayers.isEmpty && _ballPossessorIndex == null) {
                  _blinkController.stop();
                }
                return;
              }

              _startPlayerRun(i, isOpponent, List<Offset>.from(trail));
            },
            onPanCancel: () {
              setState(() {
                _activeTouchPlayerKeys.remove(pKey);
                _playerTrails.remove(pKey);
              });
              if (_activeTouchPlayerKeys.isEmpty && _runningPlayers.isEmpty && _ballPossessorIndex == null) {
                _blinkController.stop();
              }
            },
            child: AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (context, child) {
                final double blinkVal = isActive ? _blinkAnimation.value : 0.0;
                
                // Цвет команды: Синие против Красных
                final Color defaultColor = isOpponent
                    ? const Color(0xFFD32F2F)
                    : (_sportType == 'futsal' ? const Color(0xFF1565C0) : const Color(0xFF283593));

                final Color activeColor = isOpponent
                    ? const Color(0xFFFF5252)
                    : const Color(0xFFFF1744);

                final Color circleColor = isActive
                    ? Color.lerp(defaultColor, activeColor, blinkVal)!
                    : defaultColor;

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
                            color: isSelected ? const Color(0xFFFFD700) : (isActive ? Colors.white : (isOpponent ? const Color(0xFFFFCDD2) : Colors.white.withValues(alpha: 0.9))),
                            width: isSelected ? 3.2 : (isActive ? 2.6 : 1.8),
                        ),
                        boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.85),
                                blurRadius: 12.0,
                                spreadRadius: 3.5,
                              )
                            else
                          BoxShadow(
                            color: isActive
                                ? (isOpponent
                                    ? const Color(0xFFFF5252).withValues(alpha: 0.6 + blinkVal * 0.35)
                                    : const Color(0xFFFF1744).withValues(alpha: 0.55 + blinkVal * 0.4))
                                : Colors.black.withValues(alpha: 0.55),
                            blurRadius: isActive ? (10.0 + blinkVal * 8.0) : 6.0,
                            spreadRadius: isActive ? (1.5 + blinkVal * 2.5) : 0.0,
                            offset: isActive ? Offset.zero : const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (hasBall)
                              Container(
                                width: 14.0,
                                height: 14.0,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.25 + _blinkAnimation.value * 0.70),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700).withValues(alpha: _blinkAnimation.value * 0.85),
                                      blurRadius: 4.0 + _blinkAnimation.value * 5.0,
                                      spreadRadius: 1.5 + _blinkAnimation.value * 2.0,
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              numberText,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.5,
                                shadows: hasBall ? const [Shadow(color: Colors.black, blurRadius: 4)] : null,
                              ),
                            ),
                          ],
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
                        style: TextStyle(
                          color: isOpponent ? const Color(0xFFFF8A80) : Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
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
                        mainAxisSize: MainAxisSize.min,
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

// ПРЕДУПРЕЖДЕНИЕ О СКУЧИВАНИИ
class ClusterWarningPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.35, size.height * 0.44);
    const double radius = 58.0;

    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF1744).withValues(alpha: 0.45),
          const Color(0xFFFF1744).withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, auraPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final dashedPath = Path();
    const double dashAngle = 0.20;
    for (double a = 0; a < 2 * math.pi; a += dashAngle * 2) {
      dashedPath.addArc(Rect.fromCircle(center: center, radius: radius), a, dashAngle);
    }
    canvas.drawPath(dashedPath, borderPaint);

    final textSpan = const TextSpan(
      text: '⚠️ СКУЧИВАНИЕ: В ЛОВУШКЕ КРАСНЫХ!',
      style: TextStyle(
        color: Color(0xFFFF5252),
        fontSize: 9.5,
        fontWeight: FontWeight.w900,
        backgroundColor: Colors.black87,
      ),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - radius - 14));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ТЕПЛОВАЯ КАРТА
class HeatmapZonesPainter extends CustomPainter {
  final List<Offset> positions;
  final List<Map<String, dynamic>> starters;
  final bool isFutsal;

  HeatmapZonesPainter({
    required this.positions,
    required this.starters,
    required this.isFutsal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.isEmpty) return;

    final double zoneRadius = math.min(size.width, size.height) * (isFutsal ? 0.28 : 0.24);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final center = Offset(pos.dx * size.width, pos.dy * size.height);
      final player = i < starters.length ? starters[i] : null;
      final number = player?['jersey_number'] ?? (i + 1);

      final heatPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF5722).withValues(alpha: 0.42),
            const Color(0xFFFF9800).withValues(alpha: 0.26),
            const Color(0xFFFFEB3B).withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: zoneRadius));

      canvas.drawCircle(center, zoneRadius, heatPaint);

      final dashedPath = Path();
      const double dashAngle = 0.14;
      for (double a = 0; a < 2 * math.pi; a += dashAngle * 2) {
        dashedPath.addArc(
          Rect.fromCircle(center: center, radius: zoneRadius),
          a,
          dashAngle,
        );
      }
      canvas.drawPath(dashedPath, linePaint);

      final textSpan = TextSpan(
        text: 'Зона #$number',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2, center.dy - zoneRadius + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant HeatmapZonesPainter oldDelegate) => true;
}

// ПУНКТИР СО СТРЕЛКОЙ
class TrajectoryPainter extends CustomPainter {
  final List<Offset> passTrail;
  Path _createSmoothPath(List<Offset> pts, Size size) {
    final path = Path();
    if (pts.isEmpty) return path;
    final scaled = pts.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
    path.moveTo(scaled[0].dx, scaled[0].dy);
    if (scaled.length == 1) return path;
    for (int i = 0; i < scaled.length - 1; i++) {
      final p0 = scaled[i];
      final p1 = scaled[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(scaled.last.dx, scaled.last.dy);
    return path;
  }
  final List<Offset> playerTrail;
  final List<Offset> ballTrail;
  final double trailAlpha;

  TrajectoryPainter({
    this.passTrail = const [],
    required this.playerTrail,
    this.ballTrail = const [],
    this.trailAlpha = 1.0,
  });

  void _drawDashedSpline(Canvas canvas, Size size, List<Offset> points, Color color) {
    if (points.length < 2) return;

    final trailPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeMiterLimit = 1.0;

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // final pxPoints = points
    // .map((p) => Offset(p.dx * size.width, p.dy * size.height))
    // .toList();

    final path = _createSmoothPath(points, size);
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
      const double arrowSize = 12.0;

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
    if (passTrail.length >= 2) {
      final pPaint = Paint()
        ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final p1 = Offset(passTrail[0].dx * size.width, passTrail[0].dy * size.height);
      final p2 = Offset(passTrail[1].dx * size.width, passTrail[1].dy * size.height);
      final totalDist = (p2 - p1).distance;

      if (totalDist > 0) {
        final dir = (p2 - p1) / totalDist;
        const double dashLen = 7.0;
        const double spaceLen = 5.0;
        double cur = 0.0;
        while (cur < totalDist) {
          final segStart = p1 + dir * cur;
          final segLen = (cur + dashLen <= totalDist) ? dashLen : (totalDist - cur);
          final segEnd = segStart + dir * segLen;
          canvas.drawLine(segStart, segEnd, pPaint);
          cur += dashLen + spaceLen;
        }
      }
    }
    if (playerTrail.length >= 2 && trailAlpha > 0.01) {
      final Color playerLineColor = const Color(0xFFFFD54F).withValues(alpha: 0.95 * trailAlpha);
      _drawDashedSpline(canvas, size, playerTrail, playerLineColor);
    }

    if (ballTrail.length >= 2) {
      _drawDashedSpline(canvas, size, ballTrail, Colors.white.withValues(alpha: 0.9));
    }
  }

  @override
  bool shouldRepaint(covariant TrajectoryPainter oldDelegate) => true;
}

// РАЗМЕТКА ПОЛЕЙ
class FootballPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const bgDark = Color(0xFF1B3B2B);
    const bgLight = Color(0xFF224734);
    const runOffColor = Color(0xFF132A1F);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = runOffColor);

    const double padX = 14.0;
    const double padY = 22.0;
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
    const bgDark = Color(0xFF1E3F2D);
    const bgLight = Color(0xFF244A36);
    const runOffColor = Color(0xFF142C1F);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = runOffColor);

    const double padX = 14.0;
    const double padY = 22.0;
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

// ============================================================================
// АНАЛИТИЧЕСКИЙ СЛОЙ ПОЛЯ: КОРИДОРЫ ПАСА (xPass %) И ВЫСОТА ЛИНИИ ОБОРОНЫ
// ============================================================================
class _TacticalAnalyticsPainter extends CustomPainter {
  final List<Offset> bluePositions;
  final List<Offset> redPositions;
  final Offset ballPosition;
  final int? ballPossessorIndex;
  final bool ballPossessorIsOpponent;
  final bool showBall;
  final bool showPassingLanes;
  final bool showPitchControl;

  static const double _aspectY = 0.68;

  _TacticalAnalyticsPainter({
    required this.bluePositions,
    required this.redPositions,
    required this.ballPosition,
    required this.ballPossessorIndex,
    required this.ballPossessorIsOpponent,
    required this.showBall,
    this.showPassingLanes = true,
    this.showPitchControl = false,
  });

  double _metricDist(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = (a.dy - b.dy) * _aspectY;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (showPitchControl) {
      _drawPitchControlVoronoi(canvas, size);
    }
    if (showPassingLanes) {
      _drawDefensiveLines(canvas, size);
      if (showBall) {
        _drawPassingCorridors(canvas, size);
      }
    }
  }

  // Диаграмма Вороного и логистическая карта контроля территории (Fernandez & Bornn model)
  void _drawPitchControlVoronoi(Canvas canvas, Size size) {
    if (bluePositions.isEmpty && redPositions.isEmpty) return;

    const int cols = 28;
    const int rows = 18;
    final double cellW = size.width / cols;
    final double cellH = size.height / rows;

    final List<List<double>> controlGrid = List.generate(
      rows,
      (_) => List<double>.filled(cols, 0.5),
    );

    double blueWeightedSum = 0.0;
    int totalCells = rows * cols;
    final Paint cellPaint = Paint()..style = PaintingStyle.fill;

    for (int r = 0; r < rows; r++) {
      final double normY = (r + 0.5) / rows;
      for (int c = 0; c < cols; c++) {
        final double normX = (c + 0.5) / cols;
        final Offset pt = Offset(normX, normY);

        double minBlue = 99.0;
        for (final bp in bluePositions) {
          final d = _metricDist(pt, bp);
          if (d < minBlue) minBlue = d;
        }

        double minRed = 99.0;
        for (final rp in redPositions) {
          final d = _metricDist(pt, rp);
          if (d < minRed) minRed = d;
        }

        // Логистическая функция контроля точки поля
        final double blueControl = 1.0 / (1.0 + math.exp(18.0 * (minBlue - minRed)));
        controlGrid[r][c] = blueControl;
        blueWeightedSum += blueControl;

        final Rect cellRect = Rect.fromLTWH(c * cellW, r * cellH, cellW + 0.6, cellH + 0.6);
        if (blueControl > 0.53) {
          final double intensity = ((blueControl - 0.50) * 2.0).clamp(0.0, 1.0);
          cellPaint.color = const Color(0xFF1E88E5).withValues(alpha: 0.06 + 0.22 * intensity);
          canvas.drawRect(cellRect, cellPaint);
        } else if (blueControl < 0.47) {
          final double intensity = ((0.50 - blueControl) * 2.0).clamp(0.0, 1.0);
          cellPaint.color = const Color(0xFFE53935).withValues(alpha: 0.06 + 0.22 * intensity);
          canvas.drawRect(cellRect, cellPaint);
        }
      }
    }

    // Отрисовка границ ячеек Вороного (линий фронта между зонами контроля Синих и Красных)
    final Paint frontierPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.65)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final bool isBlueHere = controlGrid[r][c] >= 0.50;
        if (c + 1 < cols) {
          final bool isBlueRight = controlGrid[r][c + 1] >= 0.50;
          if (isBlueHere != isBlueRight) {
            final double x = (c + 1) * cellW;
            canvas.drawLine(Offset(x, r * cellH), Offset(x, (r + 1) * cellH), frontierPaint);
          }
        }
        if (r + 1 < rows) {
          final bool isBlueBottom = controlGrid[r + 1][c] >= 0.50;
          if (isBlueHere != isBlueBottom) {
            final double y = (r + 1) * cellH;
            canvas.drawLine(Offset(c * cellW, y), Offset((c + 1) * cellW, y), frontierPaint);
          }
        }
      }
    }

    final int blueAreaPct = ((blueWeightedSum / totalCells) * 100).round().clamp(1, 99);
    final int redAreaPct = 100 - blueAreaPct;

    _drawBadge(
      canvas,
      center: Offset(size.width * 0.50, 18),
      text: 'КОНТРОЛЬ ПОЛЯ: СИНИЕ $blueAreaPct% • $redAreaPct% КРАСНЫЕ',
      borderColor: const Color(0xFF00B0FF),
      textColor: Colors.white,
    );
  }

  void _drawDefensiveLines(Canvas canvas, Size size) {
    if (bluePositions.length > 1) {
      final outfield = bluePositions.sublist(1);
      outfield.sort((a, b) => a.dx.compareTo(b.dx));
      final double defLineX = outfield.first.dx.clamp(0.06, 0.90);
      final double px = defLineX * size.width;
      final int metersFromGoal = ((defLineX - 0.04) * 105).round().clamp(1, 95);

      if (!showPitchControl) {
        final zonePaint = Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF1E88E5).withValues(alpha: 0.15),
              const Color(0xFF1E88E5).withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTWH(0, 0, px, size.height));
        canvas.drawRect(Rect.fromLTWH(0, 0, px, size.height), zonePaint);
      }

      final chainCount = math.min(3, outfield.length);
      final chainPlayers = outfield.sublist(0, chainCount)..sort((a, b) => a.dy.compareTo(b.dy));
      if (chainPlayers.length >= 2) {
        final chainPaint = Paint()
          ..color = const Color(0xFF64B5F6).withValues(alpha: 0.60)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        for (int i = 0; i < chainPlayers.length - 1; i++) {
          final p1 = Offset(chainPlayers[i].dx * size.width, chainPlayers[i].dy * size.height);
          final p2 = Offset(chainPlayers[i + 1].dx * size.width, chainPlayers[i + 1].dy * size.height);
          _drawDashedLine(canvas, p1, p2, chainPaint, dashWidth: 5, dashSpace: 4);
        }
      }

      final linePaint = Paint()
        ..color = const Color(0xFF42A5F5).withValues(alpha: 0.85)
        ..strokeWidth = 1.6;
      _drawDashedLine(
        canvas,
        Offset(px, 8),
        Offset(px, size.height - 8),
        linePaint,
        dashWidth: 6,
        dashSpace: 4,
      );

      _drawBadge(
        canvas,
        center: Offset((px + 44).clamp(48.0, size.width - 52.0), 36),
        text: 'ОБОРОНА СИНИХ: $metersFromGoalм',
        borderColor: const Color(0xFF42A5F5),
        textColor: const Color(0xFF90CAF9),
      );
    }

    if (redPositions.length > 1) {
      final outfield = redPositions.sublist(1);
      outfield.sort((a, b) => b.dx.compareTo(a.dx));
      final double defLineX = outfield.first.dx.clamp(0.10, 0.94);
      final double px = defLineX * size.width;
      final int metersFromGoal = ((0.96 - defLineX) * 105).round().clamp(1, 95);

      if (!showPitchControl) {
        final zonePaint = Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFFE53935).withValues(alpha: 0.02),
              const Color(0xFFE53935).withValues(alpha: 0.15),
            ],
          ).createShader(Rect.fromLTWH(px, 0, size.width - px, size.height));
        canvas.drawRect(Rect.fromLTWH(px, 0, size.width - px, size.height), zonePaint);
      }

      final chainCount = math.min(3, outfield.length);
      final chainPlayers = outfield.sublist(0, chainCount)..sort((a, b) => a.dy.compareTo(b.dy));
      if (chainPlayers.length >= 2) {
        final chainPaint = Paint()
          ..color = const Color(0xFFEF5350).withValues(alpha: 0.60)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        for (int i = 0; i < chainPlayers.length - 1; i++) {
          final p1 = Offset(chainPlayers[i].dx * size.width, chainPlayers[i].dy * size.height);
          final p2 = Offset(chainPlayers[i + 1].dx * size.width, chainPlayers[i + 1].dy * size.height);
          _drawDashedLine(canvas, p1, p2, chainPaint, dashWidth: 5, dashSpace: 4);
        }
      }

      final linePaint = Paint()
        ..color = const Color(0xFFEF5350).withValues(alpha: 0.85)
        ..strokeWidth = 1.6;
      _drawDashedLine(
        canvas,
        Offset(px, 8),
        Offset(px, size.height - 8),
        linePaint,
        dashWidth: 6,
        dashSpace: 4,
      );

      _drawBadge(
        canvas,
        center: Offset((px - 48).clamp(52.0, size.width - 52.0), size.height - 20),
        text: 'ОБОРОНА КРАСНЫХ: $metersFromGoalм',
        borderColor: const Color(0xFFEF5350),
        textColor: const Color(0xFFFFCDD2),
      );
    }
  }

  void _drawPassingCorridors(Canvas canvas, Size size) {
    int? carrierIdx = ballPossessorIndex;
    bool isOpp = ballPossessorIsOpponent;

    if (carrierIdx == null) {
      double bestDist = 0.14;
      for (int i = 0; i < bluePositions.length; i++) {
        final d = _metricDist(bluePositions[i], ballPosition);
        if (d < bestDist) {
          bestDist = d;
          carrierIdx = i;
          isOpp = false;
        }
      }
      for (int i = 0; i < redPositions.length; i++) {
        final d = _metricDist(redPositions[i], ballPosition);
        if (d < bestDist) {
          bestDist = d;
          carrierIdx = i;
          isOpp = true;
        }
      }
    }

    if (carrierIdx == null) return;
    final teammates = isOpp ? redPositions : bluePositions;
    final opponents = isOpp ? bluePositions : redPositions;
    if (carrierIdx >= teammates.length) return;

    final Offset p0 = teammates[carrierIdx];
    final Offset p0Px = Offset(p0.dx * size.width, p0.dy * size.height);

    for (int i = 0; i < teammates.length; i++) {
      if (i == carrierIdx) continue;
      final Offset target = teammates[i];
      final double passDist = _metricDist(p0, target);
      if (passDist < 0.04) continue;

      final int probPct = _computePassProbability(p0, target, passDist, opponents);
      final Offset targetPx = Offset(target.dx * size.width, target.dy * size.height);

      final Color laneColor = probPct >= 70
          ? const Color(0xFF00E676)
          : (probPct >= 45 ? const Color(0xFFFFB800) : const Color(0xFFFF5252));

      final dir = targetPx - p0Px;
      final len = dir.distance;
      if (len < 10) continue;
      final perp = Offset(-dir.dy / len, dir.dx / len);

      final corridorPath = Path()
        ..moveTo(p0Px.dx + perp.dx * 3.0, p0Px.dy + perp.dy * 3.0)
        ..lineTo(targetPx.dx + perp.dx * 11.0, targetPx.dy + perp.dy * 11.0)
        ..lineTo(targetPx.dx - perp.dx * 11.0, targetPx.dy - perp.dy * 11.0)
        ..lineTo(p0Px.dx - perp.dx * 3.0, p0Px.dy - perp.dy * 3.0)
        ..close();

      final conePaint = Paint()
        ..color = laneColor.withValues(alpha: probPct >= 45 ? 0.14 : 0.07)
        ..style = PaintingStyle.fill;
      canvas.drawPath(corridorPath, conePaint);

      final axisPaint = Paint()
        ..color = laneColor.withValues(alpha: 0.85)
        ..strokeWidth = probPct >= 70 ? 2.1 : 1.4;

      if (probPct >= 45) {
        canvas.drawLine(p0Px, targetPx, axisPaint);
      } else {
        _drawDashedLine(canvas, p0Px, targetPx, axisPaint, dashWidth: 4, dashSpace: 4);
      }

      final Offset midPx = Offset(
        p0Px.dx * 0.45 + targetPx.dx * 0.55,
        p0Px.dy * 0.45 + targetPx.dy * 0.55,
      );
      _drawBadge(
        canvas,
        center: midPx,
        text: '👟 $probPct%',
        borderColor: laneColor,
        textColor: Colors.white,
      );
    }
  }

  int _computePassProbability(
    Offset p0,
    Offset target,
    double passDist,
    List<Offset> opponents,
  ) {
    final ab = target - p0;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-6) return 95;

    double minClearanceRatio = 4.0;

    for (final opp in opponents) {
      final ap = opp - p0;
      final t = (ap.dx * ab.dx + ap.dy * ab.dy) / lenSq;
      if (t < 0.05 || t > 1.05) continue;

      final clampedT = t.clamp(0.0, 1.0);
      final closest = Offset(p0.dx + ab.dx * clampedT, p0.dy + ab.dy * clampedT);
      final perpDist = _metricDist(opp, closest);
      final coneRadius = 0.026 + 0.14 * (clampedT * passDist);
      final ratio = perpDist / coneRadius;
      if (ratio < minClearanceRatio) {
        minClearanceRatio = ratio;
      }
    }

    final distFactor = math.exp(-0.42 * passDist);
    final openFactor = 1.0 - math.exp(-1.65 * minClearanceRatio * minClearanceRatio);
    final rawProb = (distFactor * openFactor * 100.0).round();
    return rawProb.clamp(5, 98);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    double dashWidth = 5,
    double dashSpace = 4,
  }) {
    final delta = p2 - p1;
    final distance = delta.distance;
    if (distance < 1) return;
    final dir = delta / distance;
    double current = 0;
    while (current < distance) {
      final end = math.min(current + dashWidth, distance);
      canvas.drawLine(p1 + dir * current, p1 + dir * end, paint);
      current += dashWidth + dashSpace;
    }
  }

  void _drawBadge(
    Canvas canvas, {
    required Offset center,
    required String text,
    required Color borderColor,
    required Color textColor,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + 10,
      height: tp.height + 5,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    final bgPaint = Paint()..color = const Color(0xE60D111A);
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TacticalAnalyticsPainter oldDelegate) => true;
}
