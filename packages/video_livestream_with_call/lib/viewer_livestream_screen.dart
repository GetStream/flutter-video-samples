import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_config.dart';
import 'floating_call_panel.dart';

/// Viewer-side livestream screen.
///
/// Watches the livestream with `LivestreamPlayer`. The viewer can ring the
/// host with a separate 1:1 call. Once the host accepts, the call shows in
/// a floating panel above the livestream so the viewer can keep watching
/// while talking.
class ViewerLivestreamScreen extends StatefulWidget {
  const ViewerLivestreamScreen({super.key, required this.livestreamCall});

  final Call livestreamCall;

  @override
  State<ViewerLivestreamScreen> createState() => _ViewerLivestreamScreenState();
}

class _ViewerLivestreamScreenState extends State<ViewerLivestreamScreen> {
  Call? _outgoingCall;
  Call? _activeSecondaryCall;
  StreamSubscription<CallState>? _outgoingCallSubscription;
  StreamSubscription<CallState>? _secondaryCallSubscription;

  bool _isCalling = false;

  @override
  void dispose() {
    _outgoingCallSubscription?.cancel();
    _secondaryCallSubscription?.cancel();
    final outgoing = _outgoingCall;
    if (outgoing != null) {
      unawaited(outgoing.leave());
    }
    final active = _activeSecondaryCall;
    if (active != null) {
      unawaited(active.leave());
    }
    unawaited(widget.livestreamCall.leave());
    super.dispose();
  }

  Future<void> _callHost() async {
    if (_isCalling || _outgoingCall != null || _activeSecondaryCall != null) {
      return;
    }

    setState(() => _isCalling = true);

    try {
      final call = StreamVideo.instance.makeCall(
        callType: StreamCallType.defaultType(),
        id: 'viewer-host-${DateTime.now().microsecondsSinceEpoch}',
        preferences: DefaultCallPreferences(
          audioConfigurationPolicy: AudioConfigurationPolicy.broadcaster(),
        ),
      );

      final getOrCreateResult = await call.getOrCreate(
        memberIds: [AppConfig.hostId],
        ringing: true,
        video: true,
      );

      if (getOrCreateResult.isFailure) {
        _showMessage('Failed to ring host.');
        await call.leave();
        return;
      }

      if (!mounted) {
        await call.leave();
        return;
      }

      // SDK auto-hibernates the livestream factory inside setActiveCall
      // when call.join() runs below.
      final joinResult = await call.join(
        connectOptions: CallConnectOptions(
          camera: TrackOption.enabled(),
          microphone: TrackOption.enabled(),
        ),
      );

      if (joinResult.isFailure) {
        _showMessage('Failed to start the call.');
        await call.leave();
        return;
      }

      if (!mounted) {
        await call.leave();
        return;
      }

      setState(() => _outgoingCall = call);
      _watchOutgoingCall(call);
    } catch (e) {
      _showMessage('Failed to ring host: $e');
    } finally {
      if (mounted) setState(() => _isCalling = false);
    }
  }

  void _watchOutgoingCall(Call call) {
    _outgoingCallSubscription?.cancel();
    _outgoingCallSubscription = call.state.valueStream.listen((state) async {
      // Host has accepted: they appear as a remote participant on this call.
      final hostJoined = state.callParticipants.any(
        (p) => !p.isLocal && p.userId == AppConfig.hostId,
      );

      if (hostJoined && _activeSecondaryCall == null) {
        await _outgoingCallSubscription?.cancel();
        _outgoingCallSubscription = null;
        if (!mounted) return;
        setState(() {
          _activeSecondaryCall = call;
          _outgoingCall = null;
        });
        _watchSecondaryCall(call);
        return;
      }

      // Call ended (host rejected, hung up, or it timed out) before connect.
      final ended = state.status.isDisconnected || state.endedAt != null;
      if (ended && _activeSecondaryCall == null) {
        await _outgoingCallSubscription?.cancel();
        _outgoingCallSubscription = null;
        if (!mounted) return;
        setState(() => _outgoingCall = null);
      }
    });
  }

  Future<void> _cancelOutgoingCall() async {
    final call = _outgoingCall;
    if (call == null) return;

    await _outgoingCallSubscription?.cancel();
    _outgoingCallSubscription = null;

    setState(() => _outgoingCall = null);

    try {
      await call.reject();
    } catch (_) {}
    try {
      await call.leave();
    } catch (_) {}
  }

  void _watchSecondaryCall(Call call) {
    _secondaryCallSubscription?.cancel();
    _secondaryCallSubscription = call.state.valueStream.listen((state) {
      final ended = state.status.isDisconnected || state.endedAt != null;
      if (ended && _activeSecondaryCall != null) {
        _endActiveCall();
      }
    });
  }

  Future<void> _endActiveCall() async {
    final call = _activeSecondaryCall;
    if (call == null) return;

    _secondaryCallSubscription?.cancel();
    _secondaryCallSubscription = null;

    setState(() => _activeSecondaryCall = null);

    try {
      await call.leave();
    } catch (_) {}
  }

  Future<void> _leaveLivestream() async {
    await _cancelOutgoingCall();
    await _endActiveCall();
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _leaveLivestream();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: _ViewerContent(call: widget.livestreamCall)),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              right: 16,
              child: _ViewerTopBar(
                call: widget.livestreamCall,
                onLeave: _leaveLivestream,
              ),
            ),
            if (_activeSecondaryCall != null)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 80,
                right: 16,
                child: FloatingCallPanel(
                  call: _activeSecondaryCall!,
                  onHangUp: _endActiveCall,
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
              child: _CallHostButton(
                isCalling: _isCalling,
                hasOutgoing: _outgoingCall != null,
                hasActive: _activeSecondaryCall != null,
                onCallHost: _callHost,
                onCancel: _cancelOutgoingCall,
              ),
            ),
            if (_outgoingCall != null)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 80,
                right: 16,
                child: _RingingIndicator(onCancel: _cancelOutgoingCall),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewerContent extends StatelessWidget {
  const _ViewerContent({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder(
      call: call,
      selector: (state) => !state.isBackstage,
      builder: (context, isLive) {
        if (!isLive) return const _OfflineOverlay();
        return LivestreamPlayer(
          call: call,
          joinBehaviour: LivestreamJoinBehaviour.autoJoinWhenLive,
          onCallDisconnected: (_) {
            if (context.mounted) Navigator.of(context).pop();
          },
        );
      },
    );
  }
}

class _OfflineOverlay extends StatelessWidget {
  const _OfflineOverlay();

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
              Text(
                'Waiting for the host…',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The livestream will start as soon as ${AppConfig.hostName} '
                'goes live.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerTopBar extends StatelessWidget {
  const _ViewerTopBar({required this.call, required this.onLeave});

  final Call call;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onLeave,
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.55),
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
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

class _CallHostButton extends StatelessWidget {
  const _CallHostButton({
    required this.isCalling,
    required this.hasOutgoing,
    required this.hasActive,
    required this.onCallHost,
    required this.onCancel,
  });

  final bool isCalling;
  final bool hasOutgoing;
  final bool hasActive;
  final VoidCallback onCallHost;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (hasActive) return const SizedBox.shrink();

    if (hasOutgoing) {
      return FilledButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.call_end),
        label: const Text('Cancel call'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.redAccent,
          minimumSize: const Size.fromHeight(56),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: isCalling ? null : onCallHost,
      icon: isCalling
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.call),
      label: Text('Call ${AppConfig.hostName}'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
    );
  }
}

class _RingingIndicator extends StatelessWidget {
  const _RingingIndicator({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Ringing ${AppConfig.hostName}…',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
