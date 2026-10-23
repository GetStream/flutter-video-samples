import 'package:flutter/material.dart';

import 'env_setup.dart';

/// Configure the values below so the app works with your Stream app.
///
/// The API key and the user tokens are not part of the source code. They are
/// read from `env/env.json` when the app starts, see [load].
///
/// Create `env/env.json` by running `scripts/generate_env.sh` from the
/// repository root, or copy `env/env.example.json` and fill it in by hand. See
/// the README for details.
class AppConfig {
  AppConfig._();

  static Map<String, String> _env = const {};

  /// Reads the values from `env/env.json`. Call before using the config.
  static Future<void> load() async => _env = await loadEnv();

  /// Your Stream API key from the Stream Dashboard
  static String get streamApiKey => _env['STREAM_API_KEY'] ?? '';

  static const String user1Id = 'alice_johnson';
  static const String user1Name = 'Alice Johnson';
  static String get user1Token => _env['STREAM_TOKEN_ALICE_JOHNSON'] ?? '';

  static const String user2Id = 'bob_smith';
  static const String user2Name = 'Bob Smith';
  static String get user2Token => _env['STREAM_TOKEN_BOB_SMITH'] ?? '';

  /// The names of the `env/env.json` entries that are missing or empty.
  static List<String> get missingEnvKeys => [
    for (final key in const [
      'STREAM_API_KEY',
      'STREAM_TOKEN_ALICE_JOHNSON',
      'STREAM_TOKEN_BOB_SMITH',
    ])
      if ((_env[key] ?? '').isEmpty) key,
  ];

  static const List<ChannelInfo> channels = [
    ChannelInfo(
      id: 'feed-gaming',
      name: 'Gaming Live',
      icon: Icons.sports_esports,
      gradient: [Color(0xFF6A1B9A), Color(0xFF1565C0)],
    ),
    ChannelInfo(
      id: 'feed-music',
      name: 'Music Sessions',
      icon: Icons.music_note,
      gradient: [Color(0xFFC62828), Color(0xFFAD1457)],
    ),
    ChannelInfo(
      id: 'feed-cooking',
      name: 'Cooking Show',
      icon: Icons.restaurant,
      gradient: [Color(0xFFE65100), Color(0xFFF9A825)],
    ),
    ChannelInfo(
      id: 'feed-fitness',
      name: 'Fitness Class',
      icon: Icons.fitness_center,
      gradient: [Color(0xFF2E7D32), Color(0xFF00897B)],
    ),
    ChannelInfo(
      id: 'feed-tech',
      name: 'Tech Talk',
      icon: Icons.computer,
      gradient: [Color(0xFF0D47A1), Color(0xFF1565C0)],
    ),
  ];
}

class ChannelInfo {
  const ChannelInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.gradient,
  });

  final String id;
  final String name;
  final IconData icon;
  final List<Color> gradient;
}
