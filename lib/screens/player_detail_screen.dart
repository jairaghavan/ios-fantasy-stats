// lib/screens/player_detail_screen.dart
import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../data/models/player.dart';
import '../data/models/game_stat.dart';

class PlayerDetailScreen extends StatefulWidget {
  final Player player;
  const PlayerDetailScreen({super.key, required this.player});

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  late Future<List<GameStat>> _gameLogFuture;
  ScoringFormat _format = ScoringFormat.ppr;

  @override
  void initState() {
    super.initState();
    _gameLogFuture = DatabaseHelper.instance.getGameLog(widget.player.playerId);
  }

  // Approximate postseason round labels. Accurate for the 18-week regular
  // season format used since the 2021 season (weeks 1-18 regular season,
  // 19+ postseason). If you bring in pre-2021 data, this mapping won't
  // apply -- those seasons had a 17-week regular season, shifting postseason
  // week numbers down by one.
  String _weekLabel(int week) {
    switch (week) {
      case 19:
        return 'WC';
      case 20:
        return 'DIV';
      case 21:
        return 'CONF';
      case 22:
        return 'SB';
      default:
        return week.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.player.fullName)),
      body: FutureBuilder<List<GameStat>>(
        future: _gameLogFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final games = snapshot.data!;
          if (games.isEmpty) {
            return const Center(child: Text('No game log data found.'));
          }

          final bySeason = <int, List<GameStat>>{};
          for (final g in games) {
            bySeason.putIfAbsent(g.season, () => []).add(g);
          }
          final seasons = bySeason.keys.toList()..sort((a, b) => b.compareTo(a));

          return DefaultTabController(
            length: seasons.length,
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1),
                TabBar(
                  isScrollable: true,
                  tabs: seasons.map((s) => Tab(text: s.toString())).toList(),
                ),
                Expanded(
                  child: TabBarView(
                    children: seasons.map((season) {
                      final seasonGames = bySeason[season]!
                        ..sort((a, b) => a.week.compareTo(b.week));
                      final regular = seasonGames.where((g) => g.week <= 18).toList();
                      final postseason = seasonGames.where((g) => g.week >= 19).toList();

                      return ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          _sectionLabel('Regular Season'),
                          _buildTable(regular),
                          if (postseason.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _sectionLabel('Postseason'),
                            _buildTable(postseason),
                          ],
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Chip(label: Text(widget.player.position)),
          const SizedBox(width: 8),
          if (widget.player.team != null) Chip(label: Text(widget.player.team!)),
          const Spacer(),
          DropdownButton<ScoringFormat>(
            value: _format,
            onChanged: (value) {
              if (value != null) setState(() => _format = value);
            },
            items: const [
              DropdownMenuItem(value: ScoringFormat.standard, child: Text('Standard')),
              DropdownMenuItem(value: ScoringFormat.half, child: Text('Half PPR')),
              DropdownMenuItem(value: ScoringFormat.ppr, child: Text('PPR')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
      ),
    );
  }

  Widget _buildTable(List<GameStat> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('No games.', style: TextStyle(color: Colors.grey)),
      );
    }

    final columns = _columnsForPosition(widget.player.position);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DataTable(
        columnSpacing: 20,
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 40,
        columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
        rows: rows.map((g) => DataRow(cells: _cellsForPosition(widget.player.position, g))).toList(),
      ),
    );
  }

  List<String> _columnsForPosition(String position) {
    switch (position) {
      case 'QB':
        return ['WK', 'CMP/ATT', 'YDS', 'TD', 'INT', 'RUSH', 'RY', 'RTD', 'FPTS'];
      case 'RB':
        return ['WK', 'ATT', 'YDS', 'TD', 'REC', 'RY', 'RTD', 'FPTS'];
      case 'WR':
      case 'TE':
        return ['WK', 'TGT', 'REC', 'YDS', 'TD', 'FPTS'];
      default:
        return ['WK', 'FPTS'];
    }
  }

  List<DataCell> _cellsForPosition(String position, GameStat g) {
    final week = Text(_weekLabel(g.week));
    final fpts = Text(
      g.pointsFor(_format).toStringAsFixed(1),
      style: const TextStyle(fontWeight: FontWeight.bold),
    );

    switch (position) {
      case 'QB':
        return [
          DataCell(week),
          DataCell(Text('${g.passCmp}/${g.passAtt}')),
          DataCell(Text('${g.passYards}')),
          DataCell(Text('${g.passTd}')),
          DataCell(Text('${g.interceptions}')),
          DataCell(Text('${g.rushAtt}')),
          DataCell(Text('${g.rushYards}')),
          DataCell(Text('${g.rushTd}')),
          DataCell(fpts),
        ];
      case 'RB':
        return [
          DataCell(week),
          DataCell(Text('${g.rushAtt}')),
          DataCell(Text('${g.rushYards}')),
          DataCell(Text('${g.rushTd}')),
          DataCell(Text('${g.receptions}')),
          DataCell(Text('${g.recYards}')),
          DataCell(Text('${g.recTd}')),
          DataCell(fpts),
        ];
      case 'WR':
      case 'TE':
        return [
          DataCell(week),
          DataCell(Text('${g.targets}')),
          DataCell(Text('${g.receptions}')),
          DataCell(Text('${g.recYards}')),
          DataCell(Text('${g.recTd}')),
          DataCell(fpts),
        ];
      default:
        return [DataCell(week), DataCell(fpts)];
    }
  }
}
