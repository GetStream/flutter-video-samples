import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

/// Compact floating panel that renders the active 1:1 call on top of the
/// livestream. Used by both the host (after accepting) and the viewer
/// (after their call is accepted) so they can keep watching the broadcast
/// while talking.
class FloatingCallPanel extends StatelessWidget {
  const FloatingCallPanel({
    super.key,
    required this.call,
    required this.onHangUp,
    this.width = 160,
    this.height = 220,
  });

  final Call call;
  final VoidCallback onHangUp;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: StreamLocalVideoTheme(
                    data: const StreamLocalVideoThemeData(
                      localVideoWidth: 64,
                      localVideoHeight: 92,
                      localVideoPadding: 6,
                    ),
                    child: StreamCallParticipants(
                      call: call,
                      layoutMode: ParticipantLayoutMode.grid,
                      callParticipantBuilder: (context, call, participant) =>
                          StreamCallParticipant(
                            key: Key(participant.uniqueParticipantKey),
                            call: call,
                            participant: participant,
                            showConnectionQualityIndicator: false,
                            showParticipantLabel: false,
                          ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.phone_in_talk,
                          size: 12,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '1:1 call',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MiniControl(
                        builder: (context) =>
                            ToggleMicrophoneOption(call: call),
                      ),
                      const SizedBox(width: 4),
                      _MiniControl(
                        builder: (context) => SizedBox(
                          width: 40,
                          height: 40,
                          child: FloatingActionButton(
                            heroTag: 'panel_hang_up_${call.callCid}',
                            mini: true,
                            backgroundColor: Colors.redAccent,
                            elevation: 0,
                            onPressed: onHangUp,
                            child: const Icon(
                              Icons.call_end,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniControl extends StatelessWidget {
  const _MiniControl({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 40, height: 40, child: builder(context));
  }
}
