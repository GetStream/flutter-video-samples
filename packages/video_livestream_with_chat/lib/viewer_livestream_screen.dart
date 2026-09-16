import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' show Channel;
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_config.dart';
import 'livestream_chat_overlay.dart';
import 'livestream_control_rail.dart';
import 'livestream_reactions.dart';
import 'livestream_top_bar.dart';

/// Viewer side: watch the stream with chat and reactions drawn on top.
///
/// `LivestreamPlayer` keeps its backstage / ended / reconnecting handling, but
/// its default controls are replaced by this screen's own overlay so the chat
/// can own the bottom of the screen.
class ViewerLivestreamScreen extends StatefulWidget {
  const ViewerLivestreamScreen({
    super.key,
    required this.call,
    required this.channel,
  });

  final Call call;
  final Channel channel;

  @override
  State<ViewerLivestreamScreen> createState() => _ViewerLivestreamScreenState();
}

class _ViewerLivestreamScreenState extends State<ViewerLivestreamScreen> {
  bool _isChatVisible = true;
  bool _isFullscreen = true;

  @override
  void dispose() {
    unawaited(widget.call.leave());
    super.dispose();
  }

  Future<void> _leave() async {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // The video stays full-bleed; the composer lifts itself over the
      // keyboard instead (see `LivestreamChatOverlay`).
      resizeToAvoidBottomInset: false,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          await _leave();
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: LivestreamPlayer(
                call: widget.call,
                joinBehaviour: LivestreamJoinBehaviour.autoJoinWhenLive,
                videoFit: _isFullscreen ? VideoFit.cover : VideoFit.contain,
                showParticipantCount: false,
                // This screen draws its own chrome.
                backButtonBuilder: (_) => const SizedBox.shrink(),
                livestreamControlsWidgetBuilder: (_, __) =>
                    const SizedBox.shrink(),
                livestreamBackstageWidgetBuilder: (_, __) =>
                    const _WaitingForHost(),
                onCallDisconnected: (_) {
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            ),
            if (_isChatVisible)
              Positioned.fill(
                child: LivestreamChatOverlay(
                  call: widget.call,
                  channel: widget.channel,
                ),
              ),
            // Above the chat overlay: reactions should float over the
            // messages, not behind their gradient scrim.
            Positioned.fill(child: FloatingReactionsLayer(call: widget.call)),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              child: LivestreamTopBar(call: widget.call),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              right: 16,
              child: LivestreamControlRail(
                buttons: [
                  LivestreamRailButton(
                    icon: Icons.close,
                    tooltip: 'Leave',
                    onPressed: _leave,
                  ),
                  LivestreamRailButton(
                    icon: _isChatVisible
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline,
                    tooltip: _isChatVisible ? 'Hide chat' : 'Show chat',
                    isActive: _isChatVisible,
                    onPressed: () =>
                        setState(() => _isChatVisible = !_isChatVisible),
                  ),
                  LivestreamRailButton(
                    icon: _isFullscreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    tooltip: _isFullscreen ? 'Fit video' : 'Fill screen',
                    onPressed: () =>
                        setState(() => _isFullscreen = !_isFullscreen),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingForHost extends StatelessWidget {
  const _WaitingForHost();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.live_tv, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Waiting for the host…', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'The livestream starts as soon as ${AppConfig.host.name} '
                'goes live.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
