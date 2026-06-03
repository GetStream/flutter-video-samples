import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'floating_call_panel.dart';

/// Host-side livestream screen.
///
/// Goes live with camera + mic enabled. When a viewer rings the host with a
/// 1:1 call, an incoming-call sheet is shown. Accepting the call:
///
///   * mutes the host's mic and camera in the livestream (the broadcast
///     keeps running for viewers, just without the host's media);
///   * joins the new 1:1 call and renders it as a floating panel on top of
///     the livestream;
///   * when the 1:1 call ends, the livestream is resumed (mic + camera
///     back on).
class HostLivestreamScreen extends StatefulWidget {
  const HostLivestreamScreen({super.key, required this.livestreamCall});

  final Call livestreamCall;

  @override
  State<HostLivestreamScreen> createState() => _HostLivestreamScreenState();
}

class _HostLivestreamScreenState extends State<HostLivestreamScreen> {
  StreamSubscription<Call?>? _incomingCallSubscription;
  StreamSubscription<CallState>? _secondaryCallSubscription;

  Call? _incomingCall;
  Call? _activeSecondaryCall;
  bool _isJoiningSecondary = false;

  @override
  void initState() {
    super.initState();
    unawaited(_goLive());
    _listenForIncomingCalls();
  }

  Future<void> _goLive() async {
    final joinResult = await widget.livestreamCall.join(
      connectOptions: CallConnectOptions(
        camera: TrackOption.enabled(),
        microphone: TrackOption.enabled(),
      ),
    );

    if (joinResult.isFailure) {
      _showMessage('Failed to join livestream.');
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final goLiveResult = await widget.livestreamCall.goLive();
    if (goLiveResult.isFailure) {
      _showMessage('Failed to go live.');
    }
  }

  void _listenForIncomingCalls() {
    _incomingCallSubscription = StreamVideo.instance.state.incomingCall.listen((
      call,
    ) {
      if (call == null) return;
      // Ignore the livestream itself and any call we're already handling.
      if (call.callCid == widget.livestreamCall.callCid) return;
      if (_activeSecondaryCall != null) return;
      if (!mounted) return;

      setState(() => _incomingCall = call);
    });
  }

  Future<void> _acceptIncomingCall() async {
    final call = _incomingCall;
    if (call == null || _isJoiningSecondary) return;

    setState(() {
      _isJoiningSecondary = true;
      _incomingCall = null;
    });

    try {
      // Pause the livestream broadcast: the host stays connected to the
      // livestream call but stops publishing audio + video so viewers no
      // longer see/hear them while the 1:1 call is active.
      await widget.livestreamCall.setMicrophoneEnabled(enabled: false);
      await widget.livestreamCall.setCameraEnabled(enabled: false);

      // The SDK auto-hibernates the livestream factory when the 1:1 joins.
      final acceptResult = await call.accept();
      if (acceptResult.isFailure) {
        _showMessage('Failed to accept call.');
        await _resumeLivestream();
        return;
      }

      final joinResult = await call.join();
      if (joinResult.isFailure) {
        _showMessage('Failed to join 1:1 call.');
        await _resumeLivestream();
        return;
      }

      if (!mounted) {
        await call.leave();
        return;
      }

      setState(() => _activeSecondaryCall = call);
      _watchSecondaryCall(call);
    } catch (e) {
      _showMessage('Failed to accept: $e');
      await _resumeLivestream();
    } finally {
      if (mounted) setState(() => _isJoiningSecondary = false);
    }
  }

  Future<void> _rejectIncomingCall() async {
    final call = _incomingCall;
    if (call == null) return;

    setState(() => _incomingCall = null);

    try {
      await call.reject();
    } catch (_) {
      // Best-effort reject; the call may already have been cancelled.
    }
  }

  void _watchSecondaryCall(Call call) {
    _secondaryCallSubscription?.cancel();
    _secondaryCallSubscription = call.state.valueStream.listen((state) {
      final ended = state.status.isDisconnected || state.endedAt != null;
      if (ended && _activeSecondaryCall != null) {
        _endSecondaryCall();
      }
    });
  }

  Future<void> _endSecondaryCall() async {
    final call = _activeSecondaryCall;
    if (call == null) return;

    _secondaryCallSubscription?.cancel();
    _secondaryCallSubscription = null;

    setState(() => _activeSecondaryCall = null);

    try {
      await call.leave();
    } catch (_) {
      // ignore
    }

    await _resumeLivestream();
  }

  Future<void> _resumeLivestream() async {
    // SDK auto-wakes the livestream factory when the 1:1 is removed from
    // activeCalls; we just need to re-enable the tracks the app muted.
    try {
      await widget.livestreamCall.setMicrophoneEnabled(enabled: true);
      await widget.livestreamCall.setCameraEnabled(enabled: true);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _endLivestream() async {
    final secondary = _activeSecondaryCall;
    if (secondary != null) {
      try {
        await secondary.leave();
      } catch (_) {}
    }

    try {
      await widget.livestreamCall.stopLive();
    } catch (_) {}

    try {
      await widget.livestreamCall.end();
    } catch (_) {}
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    _secondaryCallSubscription?.cancel();
    unawaited(_endLivestream());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        await _endLivestream();
        if (!mounted) return;
        navigator.pop();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: _HostBroadcastView(call: widget.livestreamCall),
            ),
            if (_activeSecondaryCall != null)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 80,
                right: 16,
                child: FloatingCallPanel(
                  call: _activeSecondaryCall!,
                  onHangUp: _endSecondaryCall,
                ),
              ),
            if (_isJoiningSecondary)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (_incomingCall != null)
              Positioned.fill(
                child: _IncomingCallSheet(
                  call: _incomingCall!,
                  onAccept: _acceptIncomingCall,
                  onReject: _rejectIncomingCall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HostBroadcastView extends StatelessWidget {
  const _HostBroadcastView({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder(
      call: call,
      selector: (state) =>
          state.callParticipants.where((p) => p.isVideoEnabled).toList(),
      builder: (context, broadcasters) {
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: broadcasters.isEmpty
                    ? const _PausedPlaceholder()
                    : StreamCallContent(
                        call: call,
                        callParticipantsWidgetBuilder: (context, call) =>
                            StreamCallParticipants(
                              call: call,
                              participants: broadcasters,
                            ),
                        callControlsWidgetBuilder: (_, __) =>
                            const SizedBox.shrink(),
                        callAppBarWidgetBuilder: (_, __) => null,
                      ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              right: 16,
              child: _LiveBadgeRow(call: call),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
              child: _HostControls(call: call),
            ),
          ],
        );
      },
    );
  }
}

class _PausedPlaceholder extends StatelessWidget {
  const _PausedPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pause_circle_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Livestream paused',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your camera and microphone are off while the 1:1 call is '
              'active. End the call to resume the broadcast.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadgeRow extends StatelessWidget {
  const _LiveBadgeRow({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'LIVE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        PartialCallStateBuilder(
          call: call,
          selector: (state) => state.callParticipants.length,
          builder: (context, count) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HostControls extends StatelessWidget {
  const _HostControls({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ToggleMicrophoneOption(call: call),
            ToggleCameraOption(call: call),
            FlipCameraOption(call: call),
            _EndLiveButton(call: call),
          ],
        ),
      ),
    );
  }
}

class _EndLiveButton extends StatelessWidget {
  const _EndLiveButton({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: FloatingActionButton(
        heroTag: 'end_live',
        backgroundColor: Colors.redAccent,
        elevation: 0,
        onPressed: () async {
          await call.stopLive();
          await call.end();
          if (context.mounted) Navigator.of(context).pop();
        },
        child: const Icon(Icons.call_end, color: Colors.white),
      ),
    );
  }
}

class _IncomingCallSheet extends StatelessWidget {
  const _IncomingCallSheet({
    required this.call,
    required this.onAccept,
    required this.onReject,
  });

  final Call call;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = call.state.value;
    final remoteParticipant = state.callParticipants
        .where((p) => !p.isLocal)
        .firstOrNull;
    final callerName = remoteParticipant?.name.isNotEmpty == true
        ? remoteParticipant!.name
        : remoteParticipant?.userId ?? 'A viewer';
    final callerInitial = callerName.isNotEmpty ? callerName[0] : '?';

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            children: [
              const Spacer(),
              Text(
                'Incoming call',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 56,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  callerInitial.toUpperCase(),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                callerName,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Accepting will mute you on the livestream and put the '
                'call in a floating window.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleActionButton(
                    color: Colors.redAccent,
                    icon: Icons.call_end,
                    label: 'Decline',
                    onPressed: onReject,
                  ),
                  _CircleActionButton(
                    color: Colors.green,
                    icon: Icons.call,
                    label: 'Accept',
                    onPressed: onAccept,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            heroTag: 'call_action_$label',
            backgroundColor: color,
            elevation: 0,
            onPressed: onPressed,
            child: Icon(icon, size: 32, color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}
