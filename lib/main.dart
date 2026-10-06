import 'academy_hub_screen.dart';
import 'tournament_standings_widget.dart';
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
        child: AcademyHubScreen(dynamicBlocks: _dynamicBlocks),
              ],
            ),
          ),
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
