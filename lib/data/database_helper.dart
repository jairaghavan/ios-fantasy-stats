// lib/data/database_helper.dart
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'models/player.dart';
import 'models/game_stat.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'fantasy_stats.db');

    if (!await File(dbPath).exists()) {
      final data = await rootBundle.load('assets/db/fantasy_stats.db');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }

    final db  = await openDatabase(dbPath, readOnly: false);
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM players'));
    print('Players table row count: $count');
    return db;
  }

  Future<List<Player>> searchPlayers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final db = await database;
    // Fetch a wider candidate set than we'll display -- LIKE alone can't
    // express relevance, so we rank in Dart below and then trim to 30.
    final rows = await db.query(
      'players',
      where: 'full_name LIKE ?',
      whereArgs: ['%$trimmed%'],
      limit: 150,
    );

    final players = rows.map((row) => Player.fromMap(row)).toList();
    players.sort((a, b) => _searchRank(b, trimmed).compareTo(_searchRank(a, trimmed)));

    return players.take(30).toList();
  }

  /// Higher score = more relevant. Combines how the query matches the name
  /// with whether the player is currently active.
  int _searchRank(Player player, String query) {
    final name = player.fullName.toLowerCase();
    final q = query.toLowerCase();
    int score = 0;

    if (name.startsWith(q)) {
      score += 100; // e.g. "chri" -> "Christian McCaffrey"
    } else if (name.split(' ').any((word) => word.startsWith(q))) {
      score += 60; // e.g. "chri" -> "Brady Christensen" (last name match)
    } else if (name.contains(q)) {
      score += 20; // mid-word match, e.g. "hri" inside "Christian"
    }

    if (player.status == 'ACT') {
      score += 30; // active players outrank retired/free-agent players
    }

    return score;
  }

  Future<List<GameStat>> getGameLog(String playerId) async {
    final db = await database;
    final rows = await db.query(
      'player_game_stats',
      where: 'player_id = ?',
      whereArgs: [playerId],
      orderBy: 'season DESC, week DESC',
    );
    return rows.map((row) => GameStat.fromMap(row)).toList();
  }
}