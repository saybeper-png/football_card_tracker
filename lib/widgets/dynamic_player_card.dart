import 'package:flutter/material.dart';
import '../models/player_card_hub_model.dart';
import '../models/card_skin_theme.dart';

class DynamicPlayerCard extends StatelessWidget {
  final PlayerCardHubModel model;
  final CardSkinTheme skin;
  final double width;

  const DynamicPlayerCard({
    super.key,
    required this.model,
    required this.skin,
    this.width = 280,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 1.55;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: skin.glowColor,
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: skin.backgroundColors,
                    stops: skin.backgroundStops,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: skin.innerBorderColor, width: 1.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  SizedBox(
                    height: height * 0.46,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBadgeColumn(),
                        Expanded(child: _buildAvatar()),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildName(),
                  const SizedBox(height: 6),
                  Container(
                    height: 1.5,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: skin.dividerColor,
                  ),
                  const SizedBox(height: 8),
                  _buildStatsGrid(),
                  const SizedBox(height: 8),
                  _buildFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${model.cardStats.ovr}',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: skin.primaryTextColor, height: 0.95),
        ),
        Text(
          model.personalInfo.position.toUpperCase(),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: skin.secondaryTextColor),
        ),
        if (model.cardStats.streaks.current > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: skin.badgeBackgroundColor, borderRadius: BorderRadius.circular(6)),
            child: Text(
              '🔥 ${model.cardStats.streaks.current}',
              style: TextStyle(color: skin.badgeTextColor, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar() {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 0.78, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: Center(
        child: model.personalInfo.avatarUrl != null
            ? Image.network(model.personalInfo.avatarUrl!, fit: BoxFit.contain)
            : Icon(Icons.sports_soccer_rounded, size: 85, color: skin.secondaryTextColor.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildName() {
    return Text(
      model.personalInfo.lastName.toUpperCase(),
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: skin.primaryTextColor),
    );
  }

  Widget _buildStatsGrid() {
    final a = model.cardStats.attributes;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(children: [_stat(a.spd, 'SPD'), _stat(a.dri, 'DRI'), _stat(a.tec, 'TEC')]),
        Container(width: 1, height: 42, color: skin.dividerColor),
        Column(children: [_stat(a.pas, 'PAS'), _stat(a.pwr, 'PWR'), _stat(a.wrk, 'WRK')]),
      ],
    );
  }

  Widget _stat(int val, String label) {
    return Row(
      children: [
        Text('$val ', style: TextStyle(color: skin.numbersColor, fontWeight: FontWeight.w900, fontSize: 12)),
        Text(label, style: TextStyle(color: skin.secondaryTextColor, fontWeight: FontWeight.w700, fontSize: 11)),
      ],
    );
  }

  Widget _buildFooter() {
    return Text(
      '${model.personalInfo.team?.clubName?.toUpperCase() ?? "ACADEMY"} • #${model.personalInfo.jerseyNumber ?? 10}',
      style: TextStyle(color: skin.secondaryTextColor, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
    );
  }
}