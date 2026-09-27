// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/search_screen.dart';

void main() {
  runApp(const FantasyStatsApp());
}

class FantasyStatsApp extends StatelessWidget {
  const FantasyStatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fantasy Stats',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: const SearchScreen(),
    );
  }
}