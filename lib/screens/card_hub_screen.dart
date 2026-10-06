import 'package:flutter/material.dart';
import '../models/player_card_hub_model.dart';

class CardHubScreen extends StatefulWidget {
  final PlayerCardHubModel playerModel;

  const CardHubScreen({super.key, required this.playerModel});

  @override
  State<CardHubScreen> createState() => _CardHubScreenState();
}

class _CardHubScreenState extends State<CardHubScreen>
    with SingleTickerProviderStateMixin {
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // Ограничиваем угол наклона карточки в радианах
      _tiltY += details.delta.dx * 0.005;
      _tiltX -= details.delta.dy * 0.005;
      _tiltX = _tiltX.clamp(-0.25, 0.25);
      _tiltY = _tiltY.clamp(-0.25, 0.25);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.playerModel;
    final stats = player.cardStats;
    final info = player.personalInfo;
    final xpInCurrentLevel = player.cardStats.totalXp % 500;
    final levelProgress = (xpInCurrentLevel / 500).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. ИНТЕРАКТИВНАЯ 3D-КАРТОЧКА
          GestureDetector(
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 150),
              tween: Tween(begin: 0, end: _tiltX),
              builder: (context, tiltX, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002) // Перспектива 3D
                    ..rotateX(tiltX)
                    ..rotateY(_tiltY),
                  child: _buildFutCard(info, stats),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // 2. ДРУЖЕЛЮБНЫЙ БЛОК ПРОГРЕССА УРОВНЯ
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1E2D), Color(0xFF141724)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'LVL ${stats.level}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'ЗОЛОТАЯ ЛИГА',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$xpInCurrentLevel / 500 XP',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: levelProgress,
                    minHeight: 10,
                    backgroundColor: Colors.white10,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'До ${stats.level + 1} уровня: ${500 - xpInCurrentLevel} XP',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const Text('🔥 Тренировки ускоряют рост',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. СЕТКА ХАРАКТЕРИСТИК С ЭМОДЗИ
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'НАВЫКИ И СИЛЬНЫЕ СТОРОНЫ',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              _buildStatTile(
                  '⚡ Скорость', stats.attributes.spd, const Color(0xFF00E5FF)),
              _buildStatTile(
                  '🎯 Дриблинг', stats.attributes.dri, const Color(0xFFFFD54F)),
              _buildStatTile('💥 Сила удара', stats.attributes.pwr,
                  const Color(0xFFFF5252)),
              _buildStatTile(
                  '📐 Передачи', stats.attributes.pas, const Color(0xFF69F0AE)),
              _buildStatTile(
                  '🪄 Техника', stats.attributes.tec, const Color(0xFFE040FB)),
              _buildStatTile('🛡️ Выносливость', stats.attributes.wrk,
                  const Color(0xFFFFAB40)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFutCard(dynamic info, dynamic stats) {
    return Container(
      width: 280,
      height: 390,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFDF70),
            Color(0xFFD4AF37),
            Color(0xFF8F6B12),
            Color(0xFF1E1705),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.25),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFFFECB3), width: 2),
      ),
      child: Stack(
        children: [
          // Фоновый легкий футбольный паттерн
          Positioned(
            right: -20,
            top: -20,
            child: Text('⚽',
                style: TextStyle(
                    fontSize: 140,
                    color: Colors.white.withValues(alpha: 0.05))),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Верхняя строка карточки: OVR + Позиция
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${stats.ovr}',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 0.9,
                          ),
                        ),
                        Text(
                          info.position,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFECB3),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('⭐', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    const Spacer(),
                    // Аватар игрока
                    Container(
                      width: 130,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Center(
                        child: Text('🏃‍♂️', style: TextStyle(fontSize: 75)),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Имя игрока
                Center(
                  child: Column(
                    children: [
                      Text(
                        ('${info.firstName} ${info.lastName}').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${info.team.clubName} • #${info.jerseyNumber ?? 7}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFE082),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Полоса быстрых статов внизу карточки
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat('SPD', stats.attributes.spd),
                      _buildMiniStat('DRI', stats.attributes.dri),
                      _buildMiniStat('PWR', stats.attributes.pwr),
                      _buildMiniStat('PAS', stats.attributes.pas),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
        Text(
          '$value',
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildStatTile(String title, int value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161926),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                '$value',
                style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 99).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}
