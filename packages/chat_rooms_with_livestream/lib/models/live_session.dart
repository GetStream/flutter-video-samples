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

/// The livestream currently running in [messages], or `null` if none is.
///
/// Reads newest-first and stops at the first announcement it finds, so a stream
/// that has ended does not keep an older, still-unstamped one alive.
LiveSession? liveSessionIn(Iterable<Message> messages) {
  for (final message in messages.toList().reversed) {
    if (message.isDeleted) continue;
    final session = LiveSession.fromMessage(message);
    if (session == null) continue;
    return session.isLive ? session : null;
  }
  return null;
}

/// The room's live state, derived from its messages.
///
/// Deduped on call id so the surfaces watching it only rebuild when the room
/// actually starts or stops being live, not on every message that arrives.
Stream<LiveSession?> liveSessionStream(Channel channel) =>
    (channel.state?.messagesStream ?? const Stream<List<Message>>.empty())
        .map(liveSessionIn)
        .distinct((a, b) => a?.callId == b?.callId);

/// The room's live state right now, for `initialData`.
LiveSession? currentLiveSession(Channel channel) =>
    liveSessionIn(channel.state?.messages ?? const []);

/// Builds the call id for a new broadcast in [channelId].
///
/// Deriving it from the channel id keeps every call traceable back to the room
/// it started in; the timestamp suffix keeps repeat broadcasts distinct.
String newLiveCallId(String channelId) =>
    '$channelId-live-${DateTime.now().millisecondsSinceEpoch}';
