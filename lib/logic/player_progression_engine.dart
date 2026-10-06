import '../models/player_card_hub_model.dart';

class PlayerProgressionEngine {
  static int calculateOvr(CardAttributes attr) {
    final sum = attr.dri + attr.spd + attr.pas + attr.tec + attr.wrk + attr.pwr;
    return (sum / 6.0).round().clamp(1, 99);
  }

  static CardAttributes applyWorkoutDelta({
    required CardAttributes current,
    required Map<String, int> weights,
    bool isStreakWeeklyBonus = false,
  }) {
    final streakBonus = isStreakWeeklyBonus ? 1 : 0;
    return CardAttributes(
      dri: (current.dri + (weights['dri'] ?? 0)).clamp(1, 99),
      spd: (current.spd + (weights['spd'] ?? 0)).clamp(1, 99),
      pas: (current.pas + (weights['pas'] ?? 0)).clamp(1, 99),
      tec: (current.tec + (weights['tec'] ?? 0)).clamp(1, 99),
      wrk: (current.wrk + (weights['wrk'] ?? 0) + streakBonus).clamp(1, 99),
      pwr: (current.pwr + (weights['pwr'] ?? 0)).clamp(1, 99),
    );
  }

  static CardAttributes applyHomeworkApprovalDelta({
    required CardAttributes current,
    required Map<String, num> weights,
  }) {
    int calcDelta(String key) {
      final w = weights[key];
      if (w == null || w <= 0) return 0;
      return (w * 1.5).ceil();
    }
    return CardAttributes(
      dri: (current.dri + calcDelta('dri')).clamp(1, 99),
      spd: (current.spd + calcDelta('spd')).clamp(1, 99),
      pas: (current.pas + calcDelta('pas')).clamp(1, 99),
      tec: (current.tec + calcDelta('tec')).clamp(1, 99),
      wrk: (current.wrk + calcDelta('wrk') + 1).clamp(1, 99),
      pwr: (current.pwr + calcDelta('pwr')).clamp(1, 99),
    );
  }

  static int calculateEarnedXp({required int baseRewardXp, bool isCoachApproved = false}) {
    if (!isCoachApproved) return baseRewardXp;
    return (baseRewardXp * 1.5).round();
  }

  static int calculateLevel(int totalXp) {
    if (totalXp < 0) return 1;
    return 1 + (totalXp ~/ 500);
  }
}