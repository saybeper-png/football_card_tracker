// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_card_hub_model.dart';

class ParentDashboardScreen extends StatefulWidget {
  final PlayerCardHubModel player;

  const ParentDashboardScreen({super.key, required this.player});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _redemptions = [];

  @override
  void initState() {
    super.initState();
    _loadRedemptions();
  }

  Future<void> _loadRedemptions() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('reward_redemptions')
          .select('*, parental_rewards(*)')
          .eq('player_id', widget.player.playerId);

      if (mounted) {
        setState(() {
          _redemptions = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> item, String newStatus) async {
    final supabase = Supabase.instance.client;
    final redemptionId = item['id'];
    final xpSpent = ((item['xp_spent'] as num?) ?? 0).toInt();

    try {
      await supabase
          .from('reward_redemptions')
          .update({'status': newStatus})
          .eq('id', redemptionId);

      // Если родитель отклонил заявку — возвращаем XP ребенку обратно на баланс
      if (newStatus == 'rejected') {
        final profile = await supabase
            .from('player_profiles')
            .select('spendable_xp')
            .eq('user_id', widget.player.playerId)
            .single();

        final currentSpendable = ((profile['spendable_xp'] as num?) ?? 0).toInt();
        await supabase
            .from('player_profiles')
            .update({'spendable_xp': currentSpendable + xpSpent})
            .eq('user_id', widget.player.playerId);
      }

      HapticFeedback.mediumImpact();
      _loadRedemptions();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: newStatus == 'approved' ? Colors.green[800] : Colors.orange[900],
          content: Text(
            newStatus == 'approved'
                ? 'Награда одобрена! Засчитано 🚀'
                : 'Заявка отклонена, $xpSpent XP возвращено ребенку.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Ошибка обновления: $e')),
      );
    }
  }

  void _showAddRewardDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final xpController = TextEditingController(text: '300');
    String selectedEmoji = '⭐';

    final emojis = ['⭐', '⚽', '🎮', '🍕', '🎬', '🍦', '👟', '🎟️'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1D26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Новая цель для ребенка', style: TextStyle(color: Color(0xFFFFD54F))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Выберите иконку:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: emojis.map((e) {
                    final isSel = selectedEmoji == e;
                    return ChoiceChip(
                      label: Text(e, style: const TextStyle(fontSize: 18)),
                      selected: isSel,
                      selectedColor: const Color(0xFFFFD54F).withValues(alpha: 0.3),
                      backgroundColor: Colors.white10,
                      onSelected: (_) => setDialogState(() => selectedEmoji = e),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Название награды',
                    hintText: 'Например: Поход в батутный центр',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Условие или описание',
                    hintText: 'За 3 тренировки без пропусков',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: xpController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Стоимость (XP)',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ОТМЕНА', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD54F),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                final price = int.tryParse(xpController.text.trim()) ?? 0;
                if (title.isEmpty || price <= 0) return;

                final supabase = Supabase.instance.client;
                await supabase.from('parental_rewards').insert({
                  'player_id': widget.player.playerId,
                  'parent_id': widget.player.playerId,
                  'title': title,
                  'description': descController.text.trim(),
                  'icon_emoji': selectedEmoji,
                  'price_xp': price,
                });

                if (ctx.mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Цель добавлена в магазин ребенка! 🎁')),
                );
              },
              child: const Text('ДОБАВИТЬ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _redemptions.where((r) => r['status'] == 'pending').toList();
    final history = _redemptions.where((r) => r['status'] != 'pending').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('КАБИНЕТ РОДИТЕЛЯ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadRedemptions();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFFD54F),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Новая цель', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddRewardDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD54F)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                _buildPlayerSummaryCard(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text(
                      'ЗАПРОСЫ НА ПОДТВЕРЖДЕНИЕ',
                      style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                    const SizedBox(width: 8),
                    if (pending.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
                        child: Text('${pending.length}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (pending.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF141620), borderRadius: BorderRadius.circular(16)),
                    child: const Center(
                      child: Text('Нет активных запросов от ребенка 👍', style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ),
                  )
                else
                  ...pending.map((item) => _buildPendingCard(item)),
                const SizedBox(height: 24),
                const Text(
                  'ИСТОРИЯ ВЫПОЛНЕНИЯ',
                  style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  const Text('История пуста', style: TextStyle(color: Colors.white24, fontSize: 12))
                else
                  ...history.map((item) => _buildHistoryTile(item)),
              ],
            ),
    );
  }

  Widget _buildPlayerSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2130), Color(0xFF141622)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFFFD54F).withValues(alpha: 0.2),
            child: Text('${widget.player.cardStats.ovr}', style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.player.personalInfo.firstName} ${widget.player.personalInfo.lastName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Уровень ${widget.player.cardStats.level} • Стрик: ${widget.player.cardStats.streaks.current} дн. 🔥',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> item) {
    final reward = item['parental_rewards'] as Map<String, dynamic>? ?? {};
    final xpSpent = item['xp_spent'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(reward['icon_emoji'] ?? '🎁', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reward['title'] ?? 'Награда', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                    Text('Запрошено за $xpSpent XP', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _updateStatus(item, 'rejected'),
                  child: const Text('Отклонить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _updateStatus(item, 'approved'),
                  child: const Text('Одобрить ✅', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> item) {
    final reward = item['parental_rewards'] as Map<String, dynamic>? ?? {};
    final isApproved = item['status'] == 'approved';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Text(reward['icon_emoji'] ?? '🎁', style: const TextStyle(fontSize: 20)),
      title: Text(reward['title'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
      trailing: Text(
        isApproved ? 'Выполнено ✓' : 'Отклонено',
        style: TextStyle(
          color: isApproved ? Colors.greenAccent : Colors.white30,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

