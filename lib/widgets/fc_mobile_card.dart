import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player_card_hub_model.dart';

class FcMobileCardWidget extends StatelessWidget {
  final PlayerCardHubModel player;
  final bool isWalkout;

  const FcMobileCardWidget({
    super.key,
    required this.player,
    this.isWalkout = false,
  });

  @override
  Widget build(BuildContext context) {
    final stats = player.cardStats;
    final info = player.personalInfo;
    final attrs = stats.attributes;
    final clubName = (info.team?.clubName ?? 'ACADEMY STARS').toUpperCase();
    final jerseyNum = info.jerseyNumber ?? 10;

    return Center(
      child: Container(
        width: 310,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFCCFF00).withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipPath(
          clipper: FcCardClipper(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1B2232),
                  Color(0xFF10141E),
                  Color(0xFF0A0D14),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: 40,
                  child: Transform.rotate(
                    angle: pi / 6,
                    child: CustomPaint(
                      size: const Size(180, 180),
                      painter: FcTriangleWatermarkPainter(),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${stats.ovr}',
                              style: const TextStyle(
                                fontFamily: 'Impact',
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFCCFF00),
                                letterSpacing: -1.5,
                                height: 0.9,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFFCCFF00),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Transform(
                              transform: Matrix4.skewX(-0.2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  info.position,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('🇷🇺', style: TextStyle(fontSize: 18)),
                            const SizedBox(height: 4),
                            const Text('⭐', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFCCFF00).withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text('⚽', style: TextStyle(fontSize: 70)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Transform(
                      transform: Matrix4.skewX(-0.2),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2A344A), Color(0xFF141924)],
                          ),
                          border: Border.all(
                            color: const Color(0xFFCCFF00).withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${info.firstName} ${info.lastName}'.trim().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$clubName • #$jerseyNum',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatRow('PAC', attrs.spd),
                              const SizedBox(height: 4),
                              _buildStatRow('SHO', attrs.pwr),
                              const SizedBox(height: 4),
                              _buildStatRow('PAS', attrs.pas),
                            ],
                          ),
                          Container(width: 1, height: 50, color: Colors.white12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatRow('DRI', attrs.dri),
                              const SizedBox(height: 4),
                              _buildStatRow('DEF', attrs.wrk),
                              const SizedBox(height: 4),
                              _buildStatRow('PHY', attrs.tec),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int val) {
    return Row(
      children: [
        Text(
          '$val',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class FcCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const cut = 20.0;
    path.moveTo(cut, 0);
    path.lineTo(size.width - cut, 0);
    path.lineTo(size.width, cut);
    path.lineTo(size.width, size.height - cut * 1.5);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height - cut * 1.5);
    path.lineTo(0, cut);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class FcTriangleWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCFF00).withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
