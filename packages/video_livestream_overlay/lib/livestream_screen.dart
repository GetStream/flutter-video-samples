import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  bool _scoreboardEnabled = false;

  @override
  void initState() {
    super.initState();
    _effectsManager = StreamVideoEffectsManager(widget.livestreamCall);

    _callStateSubscription = widget.livestreamCall.state.valueStream
        .distinct((previous, current) => previous.status != current.status)
        .listen((_) {});
  }

  @override
  void dispose() {
    _callStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _toggleScoreboard() async {
    if (_scoreboardEnabled) {
      await _effectsManager.disableAllFilters();
      setState(() => _scoreboardEnabled = false);
    } else {
      await _effectsManager.applyCustomEffect(
        'scoreboard',
        registerEffectProcessorCallback: () async {
          await _scoreboardChannel.registerScoreboardEffect();
          // Push the current Dart-side config so the very first rendered
          // frame already reflects the dialog's values instead of the native
          // defaults.
          final config = ScoreboardConfig.instance;
          await _scoreboardChannel.updateScoreboardState(
            homeLabel: config.homeLabel,
            awayLabel: config.awayLabel,
            homeScore: config.homeScore,
            awayScore: config.awayScore,
            periodLabel: config.periodLabel,
            clockLabel: config.clockLabel,
            mirror: config.mirror,
          );
        },
      );
      setState(() => _scoreboardEnabled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder(
      call: widget.livestreamCall,
      selector: (state) =>
          (isBackstage: state.isBackstage, endedAt: state.endedAt),
      builder: (context, callState) {
        return Scaffold(
          body: Builder(
            builder: (context) {
              if (callState.isBackstage) {
                return _BackstageView(
                  call: widget.livestreamCall,
                  callId: widget.callId,
                );
              }

              if (callState.endedAt != null) {
                return _LivestreamEndedView(call: widget.livestreamCall);
              }

              return _LivestreamLiveView(
                call: widget.livestreamCall,
                callId: widget.callId,
                isHost: widget.isHost,
                scoreboardEnabled: _scoreboardEnabled,
                onToggleScoreboard: _toggleScoreboard,
                onEditScoreboard: () => showScoreboardSettingsDialog(context),
              );
            },
          ),
        );
      },
    );
  }
}

class _BackstageView extends StatelessWidget {
  const _BackstageView({required this.call, required this.callId});

  final Call call;
  final String callId;

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder(
      call: call,
      selector: (state) =>
          state.callParticipants.where((p) => !p.roles.contains('host')).length,
      builder: (context, waitingParticipantsCount) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Call ID',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        callId,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PartialCallStateBuilder(
                  call: call,
                  selector: (state) => state.startsAt,
                  builder: (context, startsAt) {
                    return Text(
                      startsAt != null
                          ? 'Livestream starting at '
                              '${DateFormat('HH:mm').format(startsAt.toLocal())}'
                          : 'Livestream starting soon',
                      style: Theme.of(context).textTheme.titleMedium,
                    );
                  },
                ),
                if (waitingParticipantsCount > 0) ...[
                  const SizedBox(height: 8),
                  Text('$waitingParticipantsCount participants waiting'),
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => call.goLive(),
                  child: const Text('Go Live'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    call.leave();
                    Navigator.pop(context);
                  },
                  child: const Text('Leave Livestream'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LivestreamEndedView extends StatefulWidget {
  const _LivestreamEndedView({required this.call});

  final Call call;

  @override
  State<_LivestreamEndedView> createState() => _LivestreamEndedViewState();
}

class _LivestreamEndedViewState extends State<_LivestreamEndedView> {
  late Future<Result<List<CallRecording>>> _recordingsFuture;

  @override
  void initState() {
    super.initState();
    _recordingsFuture = widget.call.listRecordings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.call.leave();
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Livestream has ended'),
            FutureBuilder(
              future: _recordingsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isSuccess) {
                  final recordings = snapshot.requireData.getDataOrNull();
                  if (recordings == null || recordings.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('No recordings found'),
                    );
                  }

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      const Text('Recordings'),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: recordings.length,
                        itemBuilder: (context, index) {
                          final recording = recordings[index];
                          return ListTile(title: Text(recording.url));
                        },
                      ),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ],
        ),
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
                  if (isHost) {
                    call.stopLive();
                  } else {
                    call.leave();
                  }
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
