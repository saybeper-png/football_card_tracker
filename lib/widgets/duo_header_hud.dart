import 'package:flutter/material.dart';

class DuoHeaderHud extends StatelessWidget {
  final int streakDays;
  final int spendableXp;
  final int streakFreezes;
  final int energyPercent;

  const DuoHeaderHud({
    super.key,
    required this.streakDays,
    required this.spendableXp,
    required this.streakFreezes,
    this.energyPercent = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildBadge(
            icon: '🔥',
            label: '$streakDays',
            color: const Color(0xFFFF9600),
            bgTint: const Color(0xFFFF9600).withValues(alpha: 0.15),
          ),
          _buildBadge(
            icon: '🧊',
            label: '$streakFreezes',
            color: const Color(0xFF1CB0F6),
            bgTint: const Color(0xFF1CB0F6).withValues(alpha: 0.15),
          ),
          _buildBadge(
            icon: '💎',
            label: '$spendableXp',
            color: const Color(0xFFFFD900),
            bgTint: const Color(0xFFFFD900).withValues(alpha: 0.15),
          ),
          _buildBadge(
            icon: '⚡',
            label: '$energyPercent%',
            color: const Color(0xFF58CC02),
            bgTint: const Color(0xFF58CC02).withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String icon,
    required String label,
    required Color color,
    required Color bgTint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
