// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/player_card_hub_model.dart';
import 'models/card_skin_theme.dart';
import 'screens/modern_player_home_screen.dart';
import 'screens/skill_tree_screen.dart';
import 'screens/admin_tabs_editor_screen.dart';
import 'screens/reward_store_screen.dart';
import 'screens/parent_dashboard_screen.dart';
import 'widgets/log_workout_sheet.dart';
import 'widgets/dynamic_block_renderer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bdmvnaeawsfzurvdzaml.supabase.co',
    // ignore: deprecated_member_use
    anonKey: 'sb_publishable_SRdAWMsl-_uohVydKx6rbw_8Ng_uV6T',
  );

  runApp(const FootballApp());
}

class FootballApp extends StatelessWidget {
  const FootballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FUT Card Hub',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0D12),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final TextEditingController _pinController = TextEditingController();
  bool _isAuthenticated = false;
  String? _errorMessage;

  void _verifyPin(String value) {
    if (value.trim() == '3006') {
      setState(() {
        _isAuthenticated = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = 'Неверный пин-код! Попробуйте снова.';
      });
      _pinController.clear();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return const MainNavigationShell(currentUserId: 'demo_coach_3006');
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D12),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF14161F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFCCFF00).withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFF00).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFFCCFF00),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ВХОД В СИСТЕМУ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Введите 4-значный пин-код для доступа',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  obscureText: true,
                  obscuringCharacter: '●',
                  style: const TextStyle(
                    color: Color(0xFFCCFF00),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 14,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF0C0D12),
                    hintText: '••••',
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 26,
                      letterSpacing: 10,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFCCFF00), width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.length == 4) {
                      _verifyPin(val);
                    }
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCCFF00),
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () => _verifyPin(_pinController.text),
                  child: const Text(
                    'ВОЙТИ',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final String currentUserId;

  const MainNavigationShell({super.key, required this.currentUserId});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  late Future<PlayerCardHubModel> _playerFuture;
  List<Map<String, dynamic>> _dynamicBlocks = [];

  @override
  void initState() {
    super.initState();
    _loadPlayer();
    _fetchDynamicBlocks();
  }

  void _loadPlayer() {
    _playerFuture = _fetchPlayerProfile(widget.currentUserId);
  }

  PlayerCardHubModel _getDefaultProfile(String userId) {
    return PlayerCardHubModel(
      playerId: userId,
      personalInfo: PersonalInfo(
        firstName: 'Игрок',
        lastName: '',
        position: 'ST',
        jerseyNumber: 10,
        team: TeamInfo(clubName: 'Academy Stars', ageGroup: 'U-11'),
      ),
      cardStats: CardStats(
        ovr: 70,
        activeSkin: CardSkinType.gold,
        level: 1,
        totalXp: 0,
        xpToNextLevel: 500,
        streaks: CardStreaks(current: 0, max: 0),
        attributes: CardAttributes(spd: 50, dri: 50, tec: 50, pas: 50, pwr: 50, wrk: 50),
      ),
    );
  }

  Future<void> _fetchDynamicBlocks() async {
    try {
      final res = await Supabase.instance.client
          .from('app_tabs')
          .select()
          .eq('id', 'academy_hub')
          .maybeSingle();

      if (!mounted) return;

      if (res != null && res['blocks'] != null) {
        setState(() {
          _dynamicBlocks = List<Map<String, dynamic>>.from(res['blocks']);
        });
      }
    } catch (_) {}
  }

  Future<PlayerCardHubModel> _fetchPlayerProfile(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('player_profiles')
          .select('*, users(*)')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return _getDefaultProfile(userId);
      }

      Map<String, dynamic> user = {};
      final rawUser = response['users'];
      if (rawUser is Map<String, dynamic>) {
        user = rawUser;
      } else if (rawUser is List && rawUser.isNotEmpty && rawUser.first is Map<String, dynamic>) {
        user = rawUser.first as Map<String, dynamic>;
      }

      final skinName = (response['active_card_skin'] as String? ?? 'gold').toLowerCase();
      final skin = CardSkinType.values.firstWhere(
        (e) => e.name.toLowerCase() == skinName,
        orElse: () => CardSkinType.gold,
      );

      final totalXp = ((response['total_xp'] as num?) ?? 0).toInt();
      final currentStreak = ((response['current_streak'] as num?) ?? 0).toInt();
      final maxStreak = ((response['max_streak'] as num?) ?? 0).toInt();

      return PlayerCardHubModel(
        playerId: userId,
        personalInfo: PersonalInfo(
          firstName: user['first_name'] as String? ?? 'Игрок',
          lastName: user['last_name'] as String? ?? '',
          position: response['position'] as String? ?? 'ST',
          jerseyNumber: (response['jersey_number'] as num?)?.toInt() ?? 10,
          avatarUrl: user['avatar_url'] as String?,
          team: TeamInfo(
            clubName: response['club_name'] as String? ?? 'Academy Stars',
            ageGroup: response['age_group'] as String? ?? 'U-11',
          ),
        ),
        cardStats: CardStats(
          ovr: ((response['ovr'] as num?) ?? 70).toInt(),
          activeSkin: skin,
          level: ((response['level'] as num?) ?? 1).toInt(),
          totalXp: totalXp,
          xpToNextLevel: 500 - (totalXp % 500),
          streaks: CardStreaks(current: currentStreak, max: maxStreak),
          attributes: CardAttributes(
            spd: ((response['attr_spd'] as num?) ?? 50).toInt(),
            dri: ((response['attr_dri'] as num?) ?? 50).toInt(),
            tec: ((response['attr_tec'] as num?) ?? 50).toInt(),
            pas: ((response['attr_pas'] as num?) ?? 50).toInt(),
            pwr: ((response['attr_pwr'] as num?) ?? 50).toInt(),
            wrk: ((response['attr_wrk'] as num?) ?? 50).toInt(),
          ),
        ),
      );
    } catch (_) {
      // При любой сетевой ошибке или сбое RLS возвращаем профиль по умолчанию без краша
      return _getDefaultProfile(userId);
    }
  }

  void _openWorkoutModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LogWorkoutSheet(
        playerId: widget.currentUserId,
        onSaved: () => setState(() => _loadPlayer()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlayerCardHubModel>(
      future: _playerFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0C0D12),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFCCFF00)),
            ),
          );
        }

        final player = snapshot.data ?? _getDefaultProfile(widget.currentUserId);

        final screens = [
          ModernPlayerHomeScreen(
            player: player,
            onOpenWorkout: _openWorkoutModal,
            onRefresh: () => setState(() => _loadPlayer()),
          ),
          SkillTreeScreen(
            player: player,
            onSkillUnlocked: () => setState(() => _loadPlayer()),
          ),
          DynamicBlockRenderer(blocks: _dynamicBlocks),
          RewardStoreScreen(
            playerId: player.playerId,
            initialXp: player.cardStats.totalXp,
          ),
          Stack(
            children: [
              ParentDashboardScreen(player: player),
              Positioned(
                right: 16,
                top: 16,
                child: FloatingActionButton.extended(
                  backgroundColor: const Color(0xFFCCFF00),
                  foregroundColor: Colors.black,
                  icon: const Icon(Icons.tune),
                  label: const Text('РЕДАКТОР', style: TextStyle(fontWeight: FontWeight.w900)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => AdminTabsEditorScreen(
                          onSaved: () => _fetchDynamicBlocks(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: const Color(0xFFFFD54F).withValues(alpha: 0.2),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                      color: Color(0xFFFFD54F), fontWeight: FontWeight.w800, fontSize: 11);
                }
                return const TextStyle(color: Colors.white54, fontSize: 11);
              }),
            ),
            child: NavigationBar(
              backgroundColor: const Color(0xFF14161F),
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.credit_card_outlined, color: Colors.white54),
                  selectedIcon: Icon(Icons.credit_card, color: Color(0xFFFFD54F)),
                  label: 'Карточка',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_tree_outlined, color: Colors.white54),
                  selectedIcon: Icon(Icons.account_tree, color: Color(0xFFFFD54F)),
                  label: 'Навыки',
                ),
                NavigationDestination(
                  icon: Icon(Icons.sports_soccer_outlined, color: Colors.white54),
                  selectedIcon: Icon(Icons.sports_soccer, color: Color(0xFFFFD54F)),
                  label: 'Академия',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined, color: Colors.white54),
                  selectedIcon: Icon(Icons.storefront, color: Color(0xFFFFD54F)),
                  label: 'Магазин',
                ),
                NavigationDestination(
                  icon: Icon(Icons.family_restroom_outlined, color: Colors.white54),
                  selectedIcon: Icon(Icons.family_restroom, color: Color(0xFFFFD54F)),
                  label: 'Родителям',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
