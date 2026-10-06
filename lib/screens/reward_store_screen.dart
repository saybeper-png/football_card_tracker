import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RewardStoreScreen extends StatefulWidget {
  final String playerId;
  final int initialXp;

  const RewardStoreScreen({
    super.key,
    required this.playerId,
    required this.initialXp,
  });

  @override
  State<RewardStoreScreen> createState() => _RewardStoreScreenState();
}

class _RewardStoreScreenState extends State<RewardStoreScreen> {
  late int _currentXp;
  bool _isLoading = true;
  List<Map<String, dynamic>> _shopItems = [];
  List<Map<String, dynamic>> _parentalRewards = [];

  @override
  void initState() {
    super.initState();
    _currentXp = widget.initialXp;
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    try {
      final supabase = Supabase.instance.client;

      final items = await supabase.from('shop_items').select().eq('is_active', true);
      final rewards = await supabase
          .from('parental_rewards')
          .select()
          .eq('player_id', widget.playerId)
          .eq('is_active', true);

      if (mounted) {
        setState(() {
          _shopItems = List<Map<String, dynamic>>.from(items);
          _parentalRewards = List<Map<String, dynamic>>.from(rewards);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestParentalReward(Map<String, dynamic> reward) async {
    final price = ((reward['price_xp'] as num?) ?? 0).toInt();
    if (_currentXp < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Недостаточно XP! Проведи тренировку ⚽'),
        ),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      await supabase.from('reward_redemptions').insert({
        'player_id': widget.playerId,
        'parental_reward_id': reward['id'],
        'xp_spent': price,
        'status': 'pending',
      });

      await supabase.from('player_profiles').update({
        'spendable_xp': _currentXp - price,
      }).eq('user_id', widget.playerId);

      HapticFeedback.heavyImpact();

      setState(() => _currentXp -= price);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1B1D26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Заявка отправлена! 🚀', style: TextStyle(color: Color(0xFFFFD54F))),
          content: Text('Родителям отправлен запрос на «${reward['title']}». После подтверждения награда будет разблокирована!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ОТЛИЧНО', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('МАГАЗИН НАГРАД', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD54F), width: 1),
            ),
            child: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  '$_currentXp XP',
                  style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD54F)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'СЕМЕЙНЫЕ НАГРАДЫ',
                  style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),
                if (_parentalRewards.isEmpty)
                  const Text('Награды пока не добавлены', style: TextStyle(color: Colors.white30, fontSize: 13))
                else
                  ..._parentalRewards.map((reward) => _buildRewardCard(reward)),
                const SizedBox(height: 24),
                const Text(
                  'БУСТЕРЫ И ЭФФЕКТЫ',
                  style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),
                ..._shopItems.map((item) => _buildShopItemCard(item)),
              ],
            ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward) {
    final price = ((reward['price_xp'] as num?) ?? 0).toInt();
    final canAfford = _currentXp >= price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: canAfford ? const Color(0xFFFFD54F).withValues(alpha: 0.3) : Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(reward['icon_emoji'] ?? '🎁', style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                const SizedBox(height: 4),
                Text(reward['description'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: canAfford ? () => _requestParentalReward(reward) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD54F),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text('$price XP', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItemCard(Map<String, dynamic> item) {
    final price = ((item['price_xp'] as num?) ?? 0).toInt();
    final canAfford = _currentXp >= price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13151D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                const SizedBox(height: 4),
                Text(item['description'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: canAfford ? () {} : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text('$price XP', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
