import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' show Channel;
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'livestream_chat_overlay.dart';
import 'livestream_control_rail.dart';
import 'livestream_reactions.dart';
import 'livestream_top_bar.dart';

/// Host side: broadcast while reading the same chat the viewers see.
class HostLivestreamScreen extends StatefulWidget {
  const HostLivestreamScreen({
    super.key,
    required this.call,
    required this.channel,
  });

  final Call call;
  final Channel channel;

  @override
  State<HostLivestreamScreen> createState() => _HostLivestreamScreenState();
}

class _HostLivestreamScreenState extends State<HostLivestreamScreen> {
  bool _isChatVisible = true;

  @override
  void initState() {
    super.initState();
    unawaited(_goLive());
  }

  @override
  void dispose() {
    unawaited(widget.call.leave());
    super.dispose();
  }

  Future<void> _goLive() async {
    final joinResult = await widget.call.join(
      connectOptions: CallConnectOptions(
        camera: TrackOption.enabled(),
        microphone: TrackOption.enabled(),
      ),
    );

    if (joinResult.isFailure) {
      _showMessage('Failed to join the livestream.');
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // A co-host may already have taken the stream live; only whoever starts
    // the broadcast needs to call `goLive`.
    if (!widget.call.state.value.isBackstage) return;

    final goLiveResult = await widget.call.goLive();
    if (goLiveResult.isFailure) {
      _showMessage('Failed to go live.');
    }
  }

  Future<void> _endLivestream() async {
    // `stopLive` moves the call back to backstage so viewers see the
    // "waiting for the host" state instead of a hard disconnect.
    await widget.call.stopLive();
    if (mounted) Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          await _endLivestream();
        },
        child: Stack(
          children: [
            Positioned.fill(child: _HostPreview(call: widget.call)),
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
              child: _HostControlRail(
                call: widget.call,
                isChatVisible: _isChatVisible,
                onToggleChat: () =>
                    setState(() => _isChatVisible = !_isChatVisible),
                onEnd: _endLivestream,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the hosts see of their own broadcast.
///
/// Uses `StreamLivestreamHosts` — the same widget `LivestreamPlayer` renders
/// internally — so the host sees their broadcast laid out exactly as viewers
/// do, including when there are co-hosts. Going through `StreamCallContent`
/// instead would add an app bar and call controls and letterbox the video to
/// make room for them.
class _HostPreview extends StatelessWidget {
  const _HostPreview({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder(
      call: call,
      selector: (state) =>
          state.callParticipants.where((p) => p.isVideoEnabled).toList(),
      builder: (context, hosts) {
        if (hosts.isEmpty) return _NoVideoPlaceholder(call: call);

        // With co-hosts it stops being obvious who is who, so label the tiles.
        final showLabels = hosts.length > 1;

        return StreamLivestreamTheme(
          // The grid insets its tiles by 4px, which shows up as a border
          // around a full-screen broadcast. Drop the outer padding; the
          // between-tile spacing still separates co-hosts.
          data: StreamLivestreamTheme.of(
            context,
          ).copyWith(hostsGridPadding: EdgeInsets.zero),
          child: StreamLivestreamHosts(
            call: call,
            hosts: hosts,
            callParticipantBuilder: (context, call, host) =>
                StreamCallParticipant(
                  key: ValueKey('${host.uniqueParticipantKey}-livehost-video'),
                  rendererScopePrefix: 'livehost',
                  call: call,
                  participant: host,
                  videoFit: VideoFit.cover,
                  backgroundColor: Colors.black,
                  showParticipantLabel: showLabels,
                  showConnectionQualityIndicator: false,
                  showSpeakerBorder: showLabels,
                ),
          ),
        );
      },
    );
  }
}

/// Shown while nobody on the call is publishing video.
class _NoVideoPlaceholder extends StatelessWidget {
  const _NoVideoPlaceholder({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder(
      call: call,
      selector: (state) => state.localParticipant?.isAudioEnabled ?? false,
      builder: (context, isMicrophoneEnabled) {
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMicrophoneEnabled ? Icons.videocam_off : Icons.mic_off,
                  size: 48,
                  color: Colors.white38,
                ),
                const SizedBox(height: 12),
                Text(
                  isMicrophoneEnabled
                      ? 'Camera is off — viewers can still hear you'
                      : 'Camera and microphone are off — '
                            'you are not broadcasting',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Broadcast controls: mic, camera, flip, chat, end.
class _HostControlRail extends StatelessWidget {
  const _HostControlRail({
    required this.call,
    required this.isChatVisible,
    required this.onToggleChat,
    required this.onEnd,
  });

  final Call call;
  final bool isChatVisible;
  final VoidCallback onToggleChat;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder(
      call: call,
      selector: (state) => (
        isMicrophoneEnabled: state.localParticipant?.isAudioEnabled ?? false,
        isCameraEnabled: state.localParticipant?.isVideoEnabled ?? false,
      ),
      builder: (context, media) {
        return LivestreamControlRail(
          buttons: [
            LivestreamRailButton(
              icon: Icons.close,
              tooltip: 'End livestream',
              onPressed: onEnd,
            ),
            LivestreamRailButton(
              icon: media.isCameraEnabled ? Icons.videocam : Icons.videocam_off,
              tooltip: media.isCameraEnabled
                  ? 'Turn camera off'
                  : 'Turn camera on',
              isActive: media.isCameraEnabled,
              onPressed: () =>
                  call.setCameraEnabled(enabled: !media.isCameraEnabled),
            ),
            LivestreamRailButton(
              icon: media.isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
              tooltip: media.isMicrophoneEnabled ? 'Mute' : 'Unmute',
              isActive: media.isMicrophoneEnabled,
              onPressed: () => call.setMicrophoneEnabled(
                enabled: !media.isMicrophoneEnabled,
              ),
            ),
            LivestreamRailButton(
              icon: Icons.flip_camera_ios,
              tooltip: 'Flip camera',
              onPressed: call.flipCamera,
            ),
            LivestreamRailButton(
              icon: isChatVisible
                  ? Icons.chat_bubble
                  : Icons.chat_bubble_outline,
              tooltip: isChatVisible ? 'Hide chat' : 'Show chat',
              isActive: isChatVisible,
              onPressed: onToggleChat,
            ),
          ],
        );
      },
    );
  }
}
