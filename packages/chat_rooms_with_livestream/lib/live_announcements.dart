import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'models/live_session.dart';

/// Posts and edits a single announcement message to track a room's live Stream Video state.
///
/// ⚠️ Demo-only: This logic runs entirely on the client, so chat and video can get out of sync if
/// the broadcaster's app is closed, crashes, or can't send updates—leaving "live" banners visible even after the stream ends.
///
/// **Production:** Move this logic to your backend and update state using Stream Video webhooks,
/// e.g., `call.live_started`, `call.ended`, etc., and a server-side Stream client. This ensures
/// accurate and reliable updates, solving race conditions and keeping chat/video in sync regardless of client failures.
Future<Message> postLiveAnnouncement({
  required Channel channel,
  required LiveSession session,
  required String hostName,
}) async {
  final response = await channel.sendMessage(
    Message(
      text: '$hostName started a livestream',
      attachments: [session.toAttachment()],
    ),
  );

  final announcement = response.message;

  // Pin it, so viewers can still find it once the room gets busy.
  //
  // Live state is read from this message, and a client only holds a page of
  // history: in an active room the announcement scrolls out of that page within
  // minutes, and every live indicator goes dark while the stream is still
  // running. Pinned messages come back with the channel itself, so they stay
  // reachable no matter how much has been said since.
  //
  // Pinning is a partial update of the host's own message, so it needs no grant
  // beyond the one already used to mark the stream ended.
  try {
    await channel.pinMessage(announcement);
  } on StreamChatError catch (e) {
    // Non-fatal: `liveSessionFrom` still falls back to the loaded messages, so
    // an unpinned stream behaves exactly as it did before - it just stops being
    // discoverable once the room fills up.
    debugPrint('Could not pin the live announcement: ${e.message}');
  }

  return announcement;
}

/// Takes [channel] back out of its live state by stamping `endedAt` onto the
/// announcement posted by [postLiveAnnouncement].
///
/// Editing your own message needs no special grant, so unlike a channel-data
/// write this cannot fail for permissions - but see the file-level warning: it
/// only runs at all if the broadcaster's app is still alive to run it.
Future<void> markLiveAnnouncementEnded({
  required Channel channel,
  required Message announcement,
  required LiveSession session,
}) async {
  try {
    await channel.partialUpdateMessage(
      announcement,
      set: {
        'attachments': [session.endedNow().toAttachment().toData()],
        // Unpin in the same write. The `endedAt` stamp is what actually ends
        // the stream for readers; clearing the pin just stops a finished
        // broadcast from sitting in the room's pinned list forever.
        'pinned': false,
      },
    );
  } on StreamChatError catch (e) {
    // Best effort by design. A backend-driven implementation would retry, and
    // would not depend on this device being reachable in the first place.
    debugPrint('Could not mark the stream ended: ${e.message}');
  }
}
