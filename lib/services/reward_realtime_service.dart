import 'package:supabase_flutter/supabase_flutter.dart';

class RewardRealtimeService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _rewardChannel;

  void subscribeToPlayerRedemptions({
    required String playerId,
    required void Function(Map<String, dynamic> updatedRecord) onStatusChanged,
  }) {
    unsubscribe();
    _rewardChannel = _supabase
        .channel('redemptions_player_$playerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'reward_redemptions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'player_id', value: playerId),
          callback: (payload) => onStatusChanged(payload.newRecord),
        )
        .subscribe();
  }

  void unsubscribe() {
    if (_rewardChannel != null) {
      _supabase.removeChannel(_rewardChannel!);
      _rewardChannel = null;
    }
  }
}