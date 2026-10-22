import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'models/room.dart';

/// Makes sure every predefined room exists on Stream.
///
/// This sample has no backend, so the rooms are materialised from the client on
/// sign-in instead of by a server job:
///
/// 1. One `queryChannels` for the rooms that already exist.
/// 2. `getOrCreate` (via `watch()`) for the rest, with the room's static data.
///
/// The rooms live on the [roomChannelType] channel type, which the `user` role
/// can read and post in without being a member - so there is no join step, and
/// no `Add Own Channel Membership` grant needed. The only permission this
/// depends on is **Create Channel**, and only until the rooms exist at all;
/// after that step 2 does nothing.
Future<void> ensureRoomsExist(StreamChatClient client) async {
  final roomIds = [for (final room in predefinedRooms) room.id];

  final existing = await client
      .queryChannels(
        filter: Filter.and([
          Filter.equal('type', roomChannelType),
          Filter.in_('id', roomIds),
        ]),
        channelStateSort: const [SortOption.asc('created_at')],
        paginationParams: PaginationParams(limit: roomIds.length),
      )
      .first;

  final existingIds = {for (final channel in existing) channel.id};

  for (final room in predefinedRooms) {
    if (existingIds.contains(room.id)) continue;

    try {
      await client
          .channel(
            roomChannelType,
            id: room.id,
            extraData: {'name': room.name, 'topic': room.topic},
          )
          .watch();
    } on StreamChatError catch (e) {
      // Surfaced rather than swallowed: the usual cause is the `user` role
      // missing Create Channel on the room channel type.
      debugPrint('Could not create room "${room.id}": ${e.message}');
      rethrow;
    }
  }
}
