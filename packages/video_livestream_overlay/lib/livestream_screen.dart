import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video_filters/video_effects_manager.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'scoreboard_channel.dart';
import 'scoreboard_settings_dialog.dart';

/// Host-side livestream screen with controls for toggling and configuring the
/// scoreboard overlay filter.
///
/// The filter is registered lazily via [StreamVideoEffectsManager.applyCustomEffect],
/// which calls into `MainActivity.kt` / `AppDelegate.swift` to install the
/// native [ScoreboardVideoFilterFactory] / [ScoreboardVideoFrameProcessor].
/// Once applied, the overlay is drawn onto each captured frame before it's
/// encoded, so it shows up in the outgoing WebRTC video, on all participants,
/// and in HLS/RTMP egress.
class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({
    super.key,
    required this.livestreamCall,
    required this.callId,
    required this.isHost,
  });

  final Call livestreamCall;
  final String callId;
  final bool isHost;

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late final StreamVideoEffectsManager _effectsManager;
  final _scoreboardChannel = ScoreboardChannel();

  late StreamSubscription<CallState> _callStateSubscription;
  Timer? _clockTimer;

  bool _scoreboardEnabled = false;

  @override
  void initState() {
    super.initState();
    _effectsManager = StreamVideoEffectsManager(widget.livestreamCall);

    _callStateSubscription = widget.livestreamCall.state.valueStream
        .distinct((previous, current) => previous.status != current.status)
        .listen((_) {});

    _clockTimer = Timer.periodic(const Duration(seconds: 1), _onClockTick);
  }

  void _onClockTick(Timer timer) {
    final config = ScoreboardConfig.instance;
    if (!config.clockRunning || !_scoreboardEnabled) return;

    config.clockSeconds++;
    _scoreboardChannel.updateScoreboardState(clockLabel: config.clockLabel);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _callStateSubscription.cancel();
    _effectsManager.dispose();
    super.dispose();
  }

  Future<void> _toggleScoreboard() async {
    if (_scoreboardEnabled) {
      setState(() => _scoreboardEnabled = false);
      await _effectsManager.disableAllFilters();
    } else {
      setState(() => _scoreboardEnabled = true);
      await _effectsManager.applyCustomEffect(
        'scoreboard',
        registerEffectProcessorCallback: () async {
          await _scoreboardChannel.registerScoreboardEffect();

          final config = ScoreboardConfig.instance;
          await _scoreboardChannel.updateScoreboardState(
            homeScore: config.homeScore,
            awayScore: config.awayScore,
            clockLabel: config.clockLabel,
            mirror: config.mirror,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _LivestreamLiveView(
        call: widget.livestreamCall,
        callId: widget.callId,
        isHost: widget.isHost,
        scoreboardEnabled: _scoreboardEnabled,
        onToggleScoreboard: _toggleScoreboard,
        onEditScoreboard: () => showScoreboardSettingsDialog(context),
      ),
    );
  }
}

class _LivestreamLiveView extends StatelessWidget {
  const _LivestreamLiveView({
    required this.call,
    required this.callId,
    required this.isHost,
    required this.scoreboardEnabled,
    required this.onToggleScoreboard,
    required this.onEditScoreboard,
  });

  final Call call;
  final String callId;
  final bool isHost;
  final bool scoreboardEnabled;
  final VoidCallback onToggleScoreboard;
  final VoidCallback onEditScoreboard;

  @override
  Widget build(BuildContext context) {
    return StreamCallContainer(
      call: call,
      callContentWidgetBuilder: (context, call) {
        return PartialCallStateBuilder(
          call: call,
          selector: (state) => state.callParticipants
              .where((e) => e.roles.contains('host'))
              .toList(),
          builder: (context, hosts) {
            if (hosts.isEmpty) {
              return const Center(
                child: Text("The host's video is not available"),
              );
            }

            return StreamCallContent(
              call: call,
              callAppBarWidgetBuilder: (context, call) => CallAppBar(
                call: call,
                showBackButton: false,
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PartialCallStateBuilder(
                      call: call,
                      selector: (state) => state.callParticipants.length,
                      builder: (context, count) => Text('Viewers: $count'),
                    ),
                    Text(
                      'Call ID: $callId',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                onLeaveCallTap: () {
                  call.end();
                  Navigator.of(context).pop();
                },
              ),
              callParticipantsWidgetBuilder: (context, call) {
                return Stack(
                  children: [
                    StreamCallParticipants(call: call, participants: hosts),
                    if (isHost)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: _ScoreboardControls(
                          enabled: scoreboardEnabled,
                          onToggle: onToggleScoreboard,
                          onEdit: onEditScoreboard,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ScoreboardControls extends StatelessWidget {
  const _ScoreboardControls({
    required this.enabled,
    required this.onToggle,
    required this.onEdit,
  });

  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (enabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton.small(
              heroTag: 'edit_scoreboard',
              onPressed: onEdit,
              tooltip: 'Edit scoreboard',
              child: const Icon(Icons.edit),
            ),
          ),
        FloatingActionButton.extended(
          heroTag: 'toggle_scoreboard',
          onPressed: onToggle,
          icon: Icon(enabled ? Icons.scoreboard : Icons.scoreboard_outlined),
          label: Text(enabled ? 'Hide scoreboard' : 'Show scoreboard'),
        ),
      ],
    );
  }
}
