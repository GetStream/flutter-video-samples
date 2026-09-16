import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../models/live_session.dart';
import '../models/room.dart';
import '../theme.dart';
import 'live_watch_scope.dart';

/// Renders the `livestream` announcement attachment as a "watch now" card
/// inside the room's message list.
///
/// Registered once, globally, through
/// `StreamChat(configData: StreamChatConfigurationData(attachmentBuilders: ...))`
/// - custom builders are prepended to the SDK defaults, so every other
/// attachment type still renders the way it normally would.
class LivestreamAttachmentBuilder extends StreamAttachmentWidgetBuilder {
  @override
  bool canHandle(Message message, Map<String, List<Attachment>> attachments) {
    final announcements = attachments[livestreamAttachmentType];
    return announcements != null &&
        announcements.length == 1 &&
        announcements.first.extraData['callId'] != null;
  }

  @override
  Widget? build(
    BuildContext context,
    Message message,
    Map<String, List<Attachment>> attachments,
  ) {
    final session = LiveSession.fromAttachment(
      attachments[livestreamAttachmentType]!.first,
    );
    if (session == null) return null;

    final channel = StreamChannel.of(context).channel;
    final room = roomForChannelId(channel.id);
    final currentUserId = StreamChat.of(context).currentUser?.id;
    final isHost = currentUserId == session.hostId;

    // The room screen owns the inline player; the card just asks it to expand.
    final watchScope = LiveWatchScope.maybeOf(context);
    final alreadyWatching = watchScope?.watchedCallId == session.callId;

    // The card reads its own attachment - no other lookup. When the host ends
    // the stream they edit this message, the edit arrives over the websocket,
    // and the message list rebuilds the card in its ended state.
    final isLive = session.isLive;

    return Container(
      width: 280,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLive
              ? AppColors.live.withValues(alpha: 0.6)
              : AppColors.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (room?.accent ?? AppColors.primary).withValues(alpha: 0.45),
                  AppColors.surfaceHigh,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Center(
              child: Icon(
                isLive ? Icons.sensors_rounded : Icons.videocam_off_rounded,
                size: 34,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isLive
                      ? '${session.hostName} is live now'
                      : '${session.hostName} \u00b7 stream ended',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: !isLive || isHost || alreadyWatching
                        ? null
                        : () => watchScope?.watch(session),
                    icon: Icon(
                      alreadyWatching
                          ? Icons.sensors_rounded
                          : Icons.play_arrow_rounded,
                      size: 20,
                    ),
                    label: Text(switch ((isLive, isHost, alreadyWatching)) {
                      (false, _, _) => 'Stream ended',
                      (true, true, _) => "You're the host",
                      (true, false, true) => 'Watching',
                      (true, false, false) => 'Watch now',
                    }),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.live,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
