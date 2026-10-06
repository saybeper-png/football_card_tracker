import 'package:flutter/material.dart';
import 'card_skin_theme.dart';

@immutable
class CardAttributes {
  final int spd;
  final int dri;
  final int tec;
  final int pas;
  final int pwr;
  final int wrk;

  const CardAttributes({
    required this.spd,
    required this.dri,
    required this.tec,
    required this.pas,
    required this.pwr,
    required this.wrk,
  });

  factory CardAttributes.fromJson(Map<String, dynamic> json) => CardAttributes(
        spd: (json['spd'] as num?)?.toInt() ?? 50,
        dri: (json['dri'] as num?)?.toInt() ?? 50,
        tec: (json['tec'] as num?)?.toInt() ?? 50,
        pas: (json['pas'] as num?)?.toInt() ?? 50,
        pwr: (json['pwr'] as num?)?.toInt() ?? 50,
        wrk: (json['wrk'] as num?)?.toInt() ?? 50,
      );

  Map<String, dynamic> toJson() => {
        'spd': spd, 'dri': dri, 'tec': tec, 'pas': pas, 'pwr': pwr, 'wrk': wrk,
      };
}

@immutable
class CardStreaks {
  final int current;
  final int max;

  const CardStreaks({required this.current, required this.max});

  factory CardStreaks.fromJson(Map<String, dynamic> json) => CardStreaks(
        current: (json['current'] as num?)?.toInt() ?? 0,
        max: (json['max'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class CardStats {
  final int ovr;
  final CardSkinType activeSkin;
  final int level;
  final int totalXp;
  final int xpToNextLevel;
  final CardStreaks streaks;
  final CardAttributes attributes;

  const CardStats({
    required this.ovr,
    required this.activeSkin,
    required this.level,
    required this.totalXp,
    required this.xpToNextLevel,
    required this.streaks,
    required this.attributes,
  });

  double get levelProgressRatio => (1.0 - (xpToNextLevel / 500.0)).clamp(0.0, 1.0);

  factory CardStats.fromJson(Map<String, dynamic> json) {
    final skinStr = json['active_skin'] as String? ?? 'gold';
    final skin = CardSkinType.values.firstWhere(
      (e) => e.name.toLowerCase() == skinStr.toLowerCase(),
      orElse: () => CardSkinType.gold,
    );
    return CardStats(
      ovr: (json['ovr'] as num?)?.toInt() ?? 50,
      activeSkin: skin,
      level: (json['level'] as num?)?.toInt() ?? 1,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      xpToNextLevel: (json['xp_to_next_level'] as num?)?.toInt() ?? 500,
      streaks: CardStreaks.fromJson(json['streaks'] as Map<String, dynamic>? ?? {}),
      attributes: CardAttributes.fromJson(json['attributes'] as Map<String, dynamic>? ?? {}),
    );
  }
}

@immutable
class TeamInfo {
  final String? clubName;
  final String? ageGroup;
  const TeamInfo({this.clubName, this.ageGroup});
}

@immutable
class PersonalInfo {
  final String firstName;
  final String lastName;
  final String position;
  final int? jerseyNumber;
  final String? avatarUrl;
  final TeamInfo? team;

  const PersonalInfo({
    required this.firstName,
    required this.lastName,
    required this.position,
    this.jerseyNumber,
    this.avatarUrl,
    this.team,
  });

  String get fullName => '$firstName $lastName'.trim();
}

@immutable
class PlayerCardHubModel {
  final String playerId;
  final PersonalInfo personalInfo;
  final CardStats cardStats;

  const PlayerCardHubModel({
    required this.playerId,
    required this.personalInfo,
    required this.cardStats,
  });
}