// lib/data/models/player.dart
class Player {
  final String playerId;
  final String fullName;
  final String position;
  final String? team;
  final String? status;

  Player({
    required this.playerId,
    required this.fullName,
    required this.position,
    this.team,
    this.status,
  });

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      playerId: map['player_id'] as String,
      fullName: map['full_name'] as String,
      position: map['position'] as String,
      team: map['team'] as String?,
      status: map['status'] as String?,
    );
  }
}