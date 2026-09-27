// lib/data/models/game_stat.dart
enum ScoringFormat { standard, half, ppr }

class GameStat {
  final int id;
  final String playerId;
  final String? gameId;
  final int season;
  final int week;
  final int passAtt;
  final int passCmp;
  final int passYards;
  final int passTd;
  final int interceptions;
  final int rushAtt;
  final int rushYards;
  final int rushTd;
  final int targets;
  final int receptions;
  final int recYards;
  final int recTd;
  final int fumblesLost;
  final int twoPtConversions;
  final double fantasyPtsStd;
  final double fantasyPtsHalfPpr;
  final double fantasyPtsPpr;

  GameStat({
    required this.id,
    required this.playerId,
    this.gameId,
    required this.season,
    required this.week,
    required this.passAtt,
    required this.passCmp,
    required this.passYards,
    required this.passTd,
    required this.interceptions,
    required this.rushAtt,
    required this.rushYards,
    required this.rushTd,
    required this.targets,
    required this.receptions,
    required this.recYards,
    required this.recTd,
    required this.fumblesLost,
    required this.twoPtConversions,
    required this.fantasyPtsStd,
    required this.fantasyPtsHalfPpr,
    required this.fantasyPtsPpr,
  });

  factory GameStat.fromMap(Map<String, dynamic> map) {
    return GameStat(
      id: map['id'] as int,
      playerId: map['player_id'] as String,
      gameId: map['game_id'] as String?,
      season: map['season'] as int,
      week: map['week'] as int,
      passAtt: map['pass_att'] as int? ?? 0,
      passCmp: map['pass_cmp'] as int? ?? 0,
      passYards: map['pass_yards'] as int? ?? 0,
      passTd: map['pass_td'] as int? ?? 0,
      interceptions: map['interceptions'] as int? ?? 0,
      rushAtt: map['rush_att'] as int? ?? 0,
      rushYards: map['rush_yards'] as int? ?? 0,
      rushTd: map['rush_td'] as int? ?? 0,
      targets: map['targets'] as int? ?? 0,
      receptions: map['receptions'] as int? ?? 0,
      recYards: map['rec_yards'] as int? ?? 0,
      recTd: map['rec_td'] as int? ?? 0,
      fumblesLost: map['fumbles_lost'] as int? ?? 0,
      twoPtConversions: map['two_pt_conversions'] as int? ?? 0,
      fantasyPtsStd: (map['fantasy_pts_std'] as num?)?.toDouble() ?? 0,
      fantasyPtsHalfPpr: (map['fantasy_pts_half_ppr'] as num?)?.toDouble() ?? 0,
      fantasyPtsPpr: (map['fantasy_pts_ppr'] as num?)?.toDouble() ?? 0,
    );
  }
}

extension GameStatScoring on GameStat {
  double pointsFor(ScoringFormat format) {
    switch (format) {
      case ScoringFormat.standard:
        return fantasyPtsStd;
      case ScoringFormat.half:
        return fantasyPtsHalfPpr;
      case ScoringFormat.ppr:
        return fantasyPtsPpr;
    }
  }
}