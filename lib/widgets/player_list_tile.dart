// lib/widgets/player_list_tile.dart
import 'package:flutter/material.dart';
import '../data/models/player.dart';

class PlayerListTile extends StatelessWidget {
  final Player player;
  final VoidCallback onTap;

  const PlayerListTile({super.key, required this.player, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [player.team, player.status]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
    return ListTile(
      leading: CircleAvatar(child: Text(player.position)),
      title: Text(player.fullName),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts),
      onTap: onTap,
    );
  }
}