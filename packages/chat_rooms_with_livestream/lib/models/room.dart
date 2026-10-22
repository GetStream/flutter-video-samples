import 'package:flutter/material.dart';

/// Stream channel type backing every room in this app.
///
/// `livestream` - not because the rooms *are* livestreams, but because it is
/// Stream's open channel type: the `user` role can read and post in one without
/// being a member. The rooms here are public topic rooms that everyone is in
/// by definition, so membership bookkeeping would only get in the way. The
/// membership-gated `messaging` type is the right choice for DMs and private
/// groups instead.
const roomChannelType = 'livestream';

/// Static description of one of the predefined rooms.
///
/// Only the *identity* of a room lives on Stream (channel id, membership,
/// messages and the live-stream pointer). Presentation - emoji, accent colour,
/// topic line - stays in the app so the rooms can be restyled without touching
/// server data.
class RoomDefinition {
  const RoomDefinition({
    required this.id,
    required this.name,
    required this.topic,
    required this.emoji,
    required this.accent,
  });

  /// Stream channel id. The channel type is always [roomChannelType].
  final String id;

  /// Display name, also written to the channel's `name` on first creation.
  final String name;

  /// One-line description shown under the room name.
  final String topic;

  final String emoji;

  final Color accent;
}

/// The rooms every signed-in user lands in.
///
/// The `backstage-` prefix keeps these ids from colliding with the other
/// samples that share the same demo Stream app.
const predefinedRooms = <RoomDefinition>[
  RoomDefinition(
    id: 'backstage-lounge',
    name: 'The Lounge',
    topic: 'Say hi, hang out, no agenda',
    emoji: '🛋️',
    accent: Color(0xFF8B5CF6),
  ),
  RoomDefinition(
    id: 'backstage-gamedev',
    name: 'Game Dev',
    topic: 'Devlogs, playtests and jam chaos',
    emoji: '🎮',
    accent: Color(0xFF34D399),
  ),
  RoomDefinition(
    id: 'backstage-beatlab',
    name: 'Beat Lab',
    topic: 'Production, mixing and gear talk',
    emoji: '🎧',
    accent: Color(0xFFFBBF24),
  ),
  RoomDefinition(
    id: 'backstage-artstudio',
    name: 'Art Studio',
    topic: 'WIPs, critique and process streams',
    emoji: '🎨',
    accent: Color(0xFFF472B6),
  ),
  RoomDefinition(
    id: 'backstage-testkitchen',
    name: 'Test Kitchen',
    topic: 'Recipes and live cook-alongs',
    emoji: '🍳',
    accent: Color(0xFF38BDF8),
  ),
];

/// Looks up the presentation data for a channel id.
RoomDefinition? roomForChannelId(String? channelId) {
  for (final room in predefinedRooms) {
    if (room.id == channelId) return room;
  }
  return null;
}
