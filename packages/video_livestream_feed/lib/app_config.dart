import 'package:flutter/material.dart';

/// Configure the values below so the app works with your Stream app.
///
/// To use this project with your own Stream App credentials:
///
/// 1. Replace the `streamApiKey` below with your Stream API key from the
///    Stream Dashboard (https://dashboard.getstream.io/).
///
/// 2. Generate new user tokens for your test users using the Stream
///    token generator:
///    https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens
///
/// 3. Update the user IDs and tokens below to match your users.
///
/// IMPORTANT: The predefined API key, user credentials, and channel IDs in
/// this sample should be treated as publicly accessible demo values. If you
/// reuse them, other people running the sample may join the same livestream
/// channels.
class AppConfig {
  AppConfig._();

  static const String streamApiKey = 'mmhfdzb5evj2';

  static const String user1Id = 'alice_johnson';
  static const String user1Name = 'Alice Johnson';
  static const String user1Token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYWxpY2Vfam9obnNvbiJ9.v6-yXWgbLyykj9yt_ophmaC5FCGAG9ic6p02V09CmKQ';

  static const String user2Id = 'bob_smith';
  static const String user2Name = 'Bob Smith';
  static const String user2Token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYm9iX3NtaXRoIn0.rYCa73497wMkuiNC9P8xoEiiXlMxX_CJwBzU33-ZbHY';

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
