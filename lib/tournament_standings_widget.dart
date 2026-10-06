import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentStandingItem {
  final int rank;
  final String teamId;
  final String teamName;
  final String? teamLogo;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;

  TournamentStandingItem({
    required this.rank,
    required this.teamId,
    required this.teamName,
    this.teamLogo,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
  });

  factory TournamentStandingItem.fromMap(Map<String, dynamic> map, int rank) {
    return TournamentStandingItem(
      rank: rank,
      teamId: map['team_id'] as String,
      teamName: (map['team_name'] as String?) ?? 'оманда',
      teamLogo: map['team_logo'] as String?,
      played: (map['played'] as num?)?.toInt() ?? 0,
      won: (map['won'] as num?)?.toInt() ?? 0,
      drawn: (map['drawn'] as num?)?.toInt() ?? 0,
      lost: (map['lost'] as num?)?.toInt() ?? 0,
      goalsFor: (map['goals_for'] as num?)?.toInt() ?? 0,
      goalsAgainst: (map['goals_against'] as num?)?.toInt() ?? 0,
      goalDifference: (map['goal_difference'] as num?)?.toInt() ?? 0,
      points: (map['points'] as num?)?.toInt() ?? 0,
    );
  }
}

class TournamentStandingsWidget extends StatefulWidget {
  final String tournamentId;
  final String? title;
  final String? highlightTeamId;

  const TournamentStandingsWidget({
    super.key,
    required this.tournamentId,
    this.title = 'Турнирная таблица',
    this.highlightTeamId,
  });

  @override
  State<TournamentStandingsWidget> createState() =>
      _TournamentStandingsWidgetState();
}

class _TournamentStandingsWidgetState extends State<TournamentStandingsWidget> {
  late Future<List<TournamentStandingItem>> _standingsFuture;

  @override
  void initState() {
    super.initState();
    _fetchStandings();
  }

  @override
  void didUpdateWidget(covariant TournamentStandingsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tournamentId != widget.tournamentId) {
      _fetchStandings();
    }
  }

  void _fetchStandings() {
    setState(() {
      _standingsFuture = Supabase.instance.client
          .from('tournament_standings')
          .select()
          .eq('tournament_id', widget.tournamentId)
          .order('points', ascending: false)
          .order('goal_difference', ascending: false)
          .order('goals_for', ascending: false)
          .then((data) {
        final list = (data as List<dynamic>).cast<Map<String, dynamic>>();
        return List<TournamentStandingItem>.generate(
          list.length,
          (i) => TournamentStandingItem.fromMap(list[i], i + 1),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title ?? 'Турнирная таблица',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                tooltip: 'бновить таблицу',
                onPressed: _fetchStandings,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<TournamentStandingItem>>(
            future: _standingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: Color(0xFFFFB800)),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'шибка загрузки данных: ${snapshot.error}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final standings = snapshot.data ?? [];
              if (standings.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      ' этом турнире пока нет завершенных матчей.',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: 580,
                  child: Column(
                    children: [
                      _buildTableHeader(),
                      const Divider(color: Colors.white12, height: 1),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: standings.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (context, index) {
                          final item = standings[index];
                          final isMe = widget.highlightTeamId == item.teamId;
                          return _buildTableRow(item, isMe);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: Colors.white.withValues(alpha: 0.03),
      child: const Row(
        children: [
          SizedBox(width: 32, child: Text('#', style: _headerStyle)),
          Expanded(child: Text('луб', style: _headerStyle)),
          SizedBox(width: 36, child: Text('', textAlign: TextAlign.center, style: _headerStyle)),
          SizedBox(width: 36, child: Text('', textAlign: TextAlign.center, style: _headerStyle)),
          SizedBox(width: 36, child: Text('', textAlign: TextAlign.center, style: _headerStyle)),
          SizedBox(width: 36, child: Text('', textAlign: TextAlign.center, style: _headerStyle)),
          SizedBox(width: 54, child: Text('', textAlign: TextAlign.center, style: _headerStyle)),
          SizedBox(width: 44, child: Text('чки', textAlign: TextAlign.center, style: _headerGoldStyle)),
        ],
      ),
    );
  }

  Widget _buildTableRow(TournamentStandingItem item, bool isHighlighted) {
    Color rankColor;
    if (item.rank == 1) {
      rankColor = const Color(0xFFFFB800);
    } else if (item.rank <= 3) {
      rankColor = const Color(0xFF00E676);
    } else {
      rankColor = Colors.white54;
    }

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFFFFB800).withValues(alpha: 0.12)
            : Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Row(
              children: [
                if (item.rank <= 3)
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: rankColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  '${item.rank}',
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: item.rank <= 3 ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: item.teamLogo != null && item.teamLogo!.isNotEmpty
                      ? Image.network(
                          item.teamLogo!,
                          width: 26,
                          height: 26,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackLogo(item.teamName),
                        )
                      : _fallbackLogo(item.teamName),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isHighlighted ? const Color(0xFFFFB800) : Colors.white,
                      fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 36, child: Text('${item.played}', textAlign: TextAlign.center, style: _statStyle)),
          SizedBox(width: 36, child: Text('${item.won}', textAlign: TextAlign.center, style: _statStyle)),
          SizedBox(width: 36, child: Text('${item.drawn}', textAlign: TextAlign.center, style: _statStyle)),
          SizedBox(width: 36, child: Text('${item.lost}', textAlign: TextAlign.center, style: _statStyle)),
          SizedBox(
            width: 54,
            child: Text(
              '${item.goalsFor}:${item.goalsAgainst}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 44,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${item.points}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFB800),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackLogo(String name) {
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '⚽';
    return Container(
      width: 26,
      height: 26,
      color: Colors.white10,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    color: Colors.white54,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle _headerGoldStyle = TextStyle(
    color: Color(0xFFFFB800),
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle _statStyle = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
}