import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Attachment type used to announce a livestream in a room's message list.
const livestreamAttachmentType = 'livestream';

/// A livestream announced in a room.
///
/// **The announcement message is the single source of truth.** Going live posts
/// a message carrying a [livestreamAttachmentType] attachment; ending the
/// stream edits that same message to stamp [endedAt] onto the attachment. Every
/// surface that needs to know whether a room is live - the join card, the room
/// banner, the LIVE badge in the lobby - reads it from there.
///
/// The obvious alternative, a `live_call_id` pointer written onto the channel
/// with `updatePartial`, is a tidier data model but not one a *client* is
/// allowed to use: writing channel data needs the `Update Channel` grant, which
/// the `user` role does not hold by default. Posting and editing your own
/// message needs no special grant, so this works out of the box.
///
/// **The writes themselves live in `live_announcements.dart`, which also
/// explains why a production app should drive this from the backend rather than
/// from the broadcaster's device.**
class LiveSession {
  const LiveSession({
    required this.callId,
    required this.hostId,
    required this.hostName,
    required this.title,
    this.startedAt,
    this.endedAt,
  });

  final String callId;
  final String hostId;
  final String hostName;
  final String title;
  final DateTime? startedAt;

  /// Set when the host stops broadcasting. `null` while the stream is running.
  final DateTime? endedAt;

  bool get isLive => endedAt == null;

  LiveSession endedNow() => LiveSession(
    callId: callId,
    hostId: hostId,
    hostName: hostName,
    title: title,
    startedAt: startedAt,
    endedAt: DateTime.now().toUtc(),
  );

  /// The custom attachment carried by the announcement message.
  Attachment toAttachment() => Attachment(
    type: livestreamAttachmentType,
    uploadState: const UploadState.success(),
    extraData: {
      'callId': callId,
      'hostId': hostId,
      'hostName': hostName,
      'title': title,
      if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
    },
  );

  /// Rebuilds a session from an announcement attachment. Returns `null` for
  /// attachments that are not livestream announcements.
  static LiveSession? fromAttachment(Attachment attachment) {
    final callId = attachment.extraData['callId'] as String?;
    if (callId == null || callId.isEmpty) return null;

    return LiveSession(
      callId: callId,
      hostId: attachment.extraData['hostId'] as String? ?? '',
      hostName: attachment.extraData['hostName'] as String? ?? 'A creator',
      title: attachment.extraData['title'] as String? ?? 'Live now',
      startedAt: DateTime.tryParse(
        attachment.extraData['startedAt'] as String? ?? '',
      ),
      endedAt: DateTime.tryParse(
        attachment.extraData['endedAt'] as String? ?? '',
      ),
    );
  }

  /// The announcement carried by [message], if it has one.
  static LiveSession? fromMessage(Message message) {
    for (final attachment in message.attachments) {
      if (attachment.type != livestreamAttachmentType) continue;
      final session = fromAttachment(attachment);
      if (session != null) return session;
    }
    return null;
  }
}

/// The newest announcement in [messages], live or ended.
///
/// Kept separate from [liveSessionIn] because "no announcement here" and "the
/// announcement says the stream ended" are different answers, and
/// [liveSessionFrom] has to tell them apart to know whether to keep looking.
LiveSession? _newestAnnouncementIn(Iterable<Message> messages) {
  for (final message in messages.toList().reversed) {
    if (message.isDeleted) continue;
    final session = LiveSession.fromMessage(message);
    if (session != null) return session;
  }
  return null;
}

/// The livestream currently running in [messages], or `null` if none is.
///
/// Reads newest-first and stops at the first announcement it finds, so a stream
/// that has ended does not keep an older, still-unstamped one alive.
LiveSession? liveSessionIn(Iterable<Message> messages) {
  final session = _newestAnnouncementIn(messages);
  return session != null && session.isLive ? session : null;
}

/// The room's live state, preferring the *pinned* announcement.
///
/// [loaded] only ever holds the page of history the client currently has. In a
/// busy room the announcement is pushed out of that page within minutes - a
/// stream can still be running while every live indicator has quietly gone
/// dark, leaving no way to join it. Pinned messages come back with the channel
/// itself, independent of how much chat has happened since, so they stay
/// reachable however long the stream runs.
///
/// [loaded] remains the fallback so announcements posted before pinning
/// existed, or whose pin write failed, still work.
LiveSession? liveSessionFrom({
  required Iterable<Message> pinned,
  required Iterable<Message> loaded,
}) {
  final fromPinned = _newestAnnouncementIn(pinned);
  if (fromPinned != null) return fromPinned.isLive ? fromPinned : null;
  return liveSessionIn(loaded);
}

/// The room's live state, derived from its pinned and loaded messages.
///
/// Watches the whole channel state rather than just `messagesStream`, because
/// the pin is what makes this survive a busy room and pin changes do not show
/// up on the message stream.
///
/// Deduped on call id so the surfaces watching it only rebuild when the room
/// actually starts or stops being live, not on every message that arrives.
Stream<LiveSession?> liveSessionStream(Channel channel) =>
    (channel.state?.channelStateStream ?? const Stream<ChannelState>.empty())
        .map(
          (state) => liveSessionFrom(
            pinned: state.pinnedMessages ?? const [],
            loaded: state.messages ?? const [],
          ),
        )
        .distinct((a, b) => a?.callId == b?.callId);

/// The room's live state right now, for `initialData`.
LiveSession? currentLiveSession(Channel channel) => liveSessionFrom(
  pinned: channel.state?.pinnedMessages ?? const [],
  loaded: channel.state?.messages ?? const [],
);

/// Call id pinned at build time, so a load test knows it up front.
///
/// Empty unless the app was built with `--dart-define=STREAM_BENCH_CALL_ID=...`.
const _pinnedCallId = String.fromEnvironment('STREAM_BENCH_CALL_ID');

/// Builds the call id for a new broadcast in [channelId].
///
/// Deriving it from the channel id keeps every call traceable back to the room
/// it started in; the timestamp suffix keeps repeat broadcasts distinct.
///
/// [_pinnedCallId] overrides both, because the benchmark's bot viewers have to
/// join the call without being able to read it out of chat first. Viewers in
/// the app are unaffected either way - they take [LiveSession.callId] from the
/// announcement, so they follow whichever id the host actually used.
String newLiveCallId(String channelId) => _pinnedCallId.isNotEmpty
    ? _pinnedCallId
    : '$channelId-live-${DateTime.now().millisecondsSinceEpoch}';
