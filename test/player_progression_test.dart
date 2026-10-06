import 'package:flutter_test/flutter_test.dart';
import 'package:football_card_tracker/models/player_card_hub_model.dart';
import 'package:football_card_tracker/logic/player_progression_engine.dart';

void main() {
  group('Математика OVR и тренировок', () {
    test('Корректный расчет среднего OVR с округлением', () {
      const stats = CardAttributes(dri: 61, spd: 61, pas: 61, tec: 60, wrk: 60, pwr: 60);
      expect(PlayerProgressionEngine.calculateOvr(stats), 61);
    });

    test('Бонус тренера 1.5x с округлением вверх', () {
      const initial = CardAttributes(dri: 60, spd: 60, pas: 60, tec: 60, wrk: 60, pwr: 60);
      final updated = PlayerProgressionEngine.applyHomeworkApprovalDelta(current: initial, weights: {'dri': 1});
      expect(updated.dri, 62); // ceil(1 * 1.5) = 2 -> 60 + 2 = 62
      expect(updated.wrk, 61); // +1 дисциплина
    });

    test('Расчет уровня по XP', () {
      expect(PlayerProgressionEngine.calculateLevel(499), 1);
      expect(PlayerProgressionEngine.calculateLevel(500), 2);
    });
  });
}