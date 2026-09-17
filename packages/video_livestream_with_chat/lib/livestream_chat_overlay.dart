import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart' show Call;

import 'livestream_chat_message.dart';
import 'livestream_reactions.dart';

/// Chat overlaid on the livestream: a fading message list and a composer.
///
/// Sits in the `Stack` above the video. Only the bottom strip is hit-testable,
/// so taps on the video itself still reach the player underneath.
class LivestreamChatOverlay extends StatelessWidget {
  const LivestreamChatOverlay({
    super.key,
    required this.call,
    required this.channel,
  });

  final Call call;
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    // Chat takes the lower part of the screen; the host stays visible above it.
    final chatHeight = MediaQuery.sizeOf(context).height * 0.34;

    // The player fills the screen, so the composer has to lift itself above
    // the keyboard instead of relying on `Scaffold.resizeToAvoidBottomInset`.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return StreamChannel(
      channel: channel,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          // A light scrim, not a panel: it only has to lift the text off the
          // video. The stream stays visible all the way to the bottom of the
          // screen, and the message shadows do the rest of the legibility work.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.28),
                Colors.black.withValues(alpha: 0.5),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: chatHeight, child: const _FadingMessageList()),
              Padding(
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: keyboardInset > 0
                      ? keyboardInset + 8
                      : safeBottom + 8,
                ),
                child: _Composer(call: call),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The message list, faded out at the top so it melts into the video.
class _FadingMessageList extends StatelessWidget {
  const _FadingMessageList();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      // `dstIn` keeps the list's pixels only where the gradient is opaque,
      // which makes older messages dissolve towards the top edge.
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
        stops: [0, 0.35],
      ).createShader(bounds),
      child: StreamMessageListView(
        // Chrome that makes sense in a full chat screen but only gets in the
        // way when the list is a transparent strip over a video.
        showScrollToBottom: false,
        showUnreadIndicator: false,
        showFloatingDateDivider: false,
        showConnectionStateTile: false,
        paginationLimit: 30,
        dateDividerBuilder: (_) => const SizedBox.shrink(),
        loadingBuilder: (_) => const SizedBox.shrink(),
        emptyBuilder: (_) => const SizedBox.shrink(),
        errorBuilder: (_, __) => const SizedBox.shrink(),
        spacingWidgetBuilder: (_, __) => const SizedBox(height: 2),
        systemMessageBuilder: (_, message) =>
            LivestreamSystemMessage(message: message),
        messageBuilder: (_, details, __, ___) =>
            LivestreamChatMessage(message: details.message),
      ),
    );
  }
}

/// Message input plus the two quick-reaction buttons.
class _Composer extends StatelessWidget {
  const _Composer({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            // The composer's own background is transparent (see
            // `buildChatOverlayTheme`), so this is the pill you see.
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(24),
            ),
            child: StreamMessageInput(
              // Keep the composer to a single line of actions: a broadcast
              // chat doesn't need slash commands, threads or mentions.
              showCommandsButton: false,
              enableVoiceRecording: false,
              enableMentionsOverlay: false,
              allowedAttachmentPickerTypes: const [AttachmentPickerType.images],
              hintGetter: (_, __) => 'Message',
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              enableSafeArea: false,
            ),
          ),
        ),
        const SizedBox(width: 6),
        ReactionButton(call: call, reaction: LivestreamReaction.heart),
        const SizedBox(width: 4),
        ReactionButton(call: call, reaction: LivestreamReaction.clap),
      ],
    );
  }
}
