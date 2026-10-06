import 'package:flutter/material.dart';

enum CardSkinType { gold, totw, icon }

@immutable
class CardSkinTheme {
  final CardSkinType type;
  final String title;
  final List<Color> backgroundColors;
  final List<double> backgroundStops;
  final Color innerBorderColor;
  final Color glowColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color numbersColor;
  final Color dividerColor;
  final Color badgeBackgroundColor;
  final Color badgeTextColor;

  const CardSkinTheme({
    required this.type,
    required this.title,
    required this.backgroundColors,
    required this.backgroundStops,
    required this.innerBorderColor,
    required this.glowColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.numbersColor,
    required this.dividerColor,
    required this.badgeBackgroundColor,
    required this.badgeTextColor,
  });

  factory CardSkinTheme.gold() => const CardSkinTheme(
        type: CardSkinType.gold,
        title: 'Rare Gold',
        backgroundColors: [Color(0xFFFFFAEB), Color(0xFFE8C868), Color(0xFFB88E28), Color(0xFF875E12)],
        backgroundStops: [0.0, 0.35, 0.70, 1.0],
        innerBorderColor: Color(0xD8FFF2B2),
        glowColor: Color(0x66D4AF37),
        primaryTextColor: Color(0xFF261803),
        secondaryTextColor: Color(0xFF47330B),
        numbersColor: Color(0xFF261903),
        dividerColor: Color(0x665A410D),
        badgeBackgroundColor: Color(0xD92A1C03),
        badgeTextColor: Color(0xFFFFD54F),
      );

  factory CardSkinTheme.totw() => const CardSkinTheme(
        type: CardSkinType.totw,
        title: 'Team of the Week',
        backgroundColors: [Color(0xFF2B2822), Color(0xFF131316), Color(0xFF09090B), Color(0xFF040405)],
        backgroundStops: [0.0, 0.3, 0.7, 1.0],
        innerBorderColor: Color(0xFFFFD700),
        glowColor: Color(0x88FFB300),
        primaryTextColor: Color(0xFFFFFFFF),
        secondaryTextColor: Color(0xFFFFD54F),
        numbersColor: Color(0xFFFFE082),
        dividerColor: Color(0x55FFD700),
        badgeBackgroundColor: Color(0xE6FFB300),
        badgeTextColor: Color(0xFF0B0B0E),
      );

  factory CardSkinTheme.icon() => const CardSkinTheme(
        type: CardSkinType.icon,
        title: 'Prime Icon',
        backgroundColors: [Color(0xFFFFFFFF), Color(0xFFF7F3EA), Color(0xFFE2DAC8), Color(0xFFB5A68B)],
        backgroundStops: [0.0, 0.35, 0.75, 1.0],
        innerBorderColor: Color(0xFFC7A76D),
        glowColor: Color(0x55E0C28A),
        primaryTextColor: Color(0xFF1C1917),
        secondaryTextColor: Color(0xFF5A4D3B),
        numbersColor: Color(0xFF1F1C18),
        dividerColor: Color(0x408A7450),
        badgeBackgroundColor: Color(0xFF1C1917),
        badgeTextColor: Color(0xFFEAD2A8),
      );

  static CardSkinTheme fromType(CardSkinType type) {
    switch (type) {
      case CardSkinType.gold: return CardSkinTheme.gold();
      case CardSkinType.totw: return CardSkinTheme.totw();
      case CardSkinType.icon: return CardSkinTheme.icon();
    }
  }
}