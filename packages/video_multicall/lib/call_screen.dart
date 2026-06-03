import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_config.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.call,
    required this.initialRoomId,
  });

  final Call call;
  final String initialRoomId;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final _RoomSession _alphaRoom;
  late final _RoomSession _betaRoom;
  _RoomSession? _activeRoom;

  bool _isInitializing = true;
  bool _isBusy = false;

  List<_RoomSession> get _rooms => [_alphaRoom, _betaRoom];

  @override
  void initState() {
    super.initState();

    _alphaRoom = _RoomSession(
      roomId: AppConfig.roomAlphaId,
      roomName: AppConfig.roomAlphaName,
      call: widget.initialRoomId == AppConfig.roomAlphaId ? widget.call : null,
    );

    _betaRoom = _RoomSession(
      roomId: AppConfig.roomBravoId,
      roomName: AppConfig.roomBravoName,
      call: widget.initialRoomId == AppConfig.roomBravoId ? widget.call : null,
    );

    _activeRoom = widget.initialRoomId == AppConfig.roomAlphaId
        ? _alphaRoom
        : _betaRoom;

    unawaited(_joinInitialRoom());
  }

  Future<void> _joinInitialRoom() async {
    final activeRoom = _activeRoom;
    if (activeRoom == null) return;

    final joined = await _joinRoom(
      activeRoom,
      mediaPreferences: const _MediaPreferences.enabled(),
    );

    if (!mounted) return;

    if (!joined) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isInitializing = false);
  }

  _RoomSession _otherRoom(_RoomSession room) {
    return identical(room, _alphaRoom) ? _betaRoom : _alphaRoom;
  }

  _MediaPreferences _currentMediaPreferences() {
    final localParticipant = _activeRoom?.call?.state.value.localParticipant;
    return _MediaPreferences(
      microphoneEnabled: localParticipant?.isAudioEnabled ?? true,
      cameraEnabled: localParticipant?.isVideoEnabled ?? true,
    );
  }

  void _setBusy(bool value) {
    if (mounted) {
      setState(() => _isBusy = value);
    } else {
      _isBusy = value;
    }
  }

  void _setActiveRoom(_RoomSession? room) {
    if (mounted) {
      setState(() => _activeRoom = room);
    } else {
      _activeRoom = room;
    }
  }

  void _setRoomJoining(_RoomSession room, bool value) {
    if (mounted) {
      setState(() => room.isJoining = value);
    } else {
      room.isJoining = value;
    }
  }

  Future<bool> _joinRoom(
    _RoomSession room, {
    required _MediaPreferences mediaPreferences,
  }) async {
    if (room.isJoining) return true;

    var call = room.call;
    if (call?.state.value.status.isConnected == true) {
      return true;
    }

    _setRoomJoining(room, true);

    try {
      call ??= StreamVideo.instance.makeCall(
        callType: StreamCallType.defaultType(),
        id: room.roomId,
      );

      room.call = call;

      final getOrCreateResult = await call.getOrCreate();
      if (getOrCreateResult.isFailure) {
        _showMessage('Failed to prepare ${room.roomName}.');
        await call.leave();
        room.call = null;
        return false;
      }

      final joinResult = await call.join(
        connectOptions: CallConnectOptions(
          camera: mediaPreferences.cameraEnabled
              ? TrackOption.enabled()
              : TrackOption.disabled(),
          microphone: mediaPreferences.microphoneEnabled
              ? TrackOption.enabled()
              : TrackOption.disabled(),
        ),
      );

      if (joinResult.isFailure) {
        _showMessage('Failed to join ${room.roomName}.');
        await call.leave();
        room.call = null;
        return false;
      }

      return true;
    } catch (e) {
      _showMessage('Failed to join ${room.roomName}: $e');
      room.call = null;
      return false;
    } finally {
      _setRoomJoining(room, false);
    }
  }

  Future<void> _applyLocalMedia(
    _RoomSession room,
    _MediaPreferences mediaPreferences,
  ) async {
    final call = room.call;
    if (call == null) return;

    await call.setMicrophoneEnabled(
      enabled: mediaPreferences.microphoneEnabled,
    );
    await call.setCameraEnabled(enabled: mediaPreferences.cameraEnabled);
  }

  Future<void> _switchRoom() async {
    final currentRoom = _activeRoom;
    final targetRoom = currentRoom == null ? null : _otherRoom(currentRoom);

    if (_isBusy ||
        currentRoom == null ||
        currentRoom.call == null ||
        targetRoom?.call == null) {
      return;
    }

    final mediaPreferences = _currentMediaPreferences();

    _setBusy(true);

    try {
      // Stop publishing local media on the room we are leaving focus on.
      await _applyLocalMedia(currentRoom, const _MediaPreferences.disabled());

      // Hand over audio: suspendAudio releases mic/speaker holds and disables tracks,
      // while resumeAudio restores the target call's factory and track states.
      await currentRoom.call!.suspendAudio();
      await targetRoom!.call!.resumeAudio();

      // Restore the user's mic/camera preferences on the now-active room.
      await _applyLocalMedia(targetRoom, mediaPreferences);

      _setActiveRoom(targetRoom);
    } catch (e) {
      _showMessage('Failed to switch rooms: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _leaveRoom(_RoomSession room) async {
    final call = room.call;
    if (_isBusy || call == null) return;

    final wasActive = identical(room, _activeRoom);

    _setBusy(true);

    try {
      await call.leave();
      room.call = null;

      if (wasActive) {
        // When the active room leaves while the other is still joined, the
        // SDK auto-resumes the remaining call's audio.
        // Promote it in our UI to match that.
        final remaining = _otherRoom(room);
        _setActiveRoom(remaining.call != null ? remaining : null);
      }
    } catch (e) {
      _showMessage('Failed to leave ${room.roomName}: $e');
    } finally {
      _setBusy(false);
    }

    if (!mounted) return;

    if (_alphaRoom.call == null && _betaRoom.call == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {});
    }
  }

  Future<void> _leaveAllRoomsAndExit() async {
    if (_isBusy) return;

    _setBusy(true);

    try {
      for (final room in _rooms) {
        final call = room.call;
        if (call == null) continue;
        await call.leave();
        room.call = null;
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildRoomPane(_RoomSession room) {
    return Expanded(
      child: _RoomPane(
        room: room,
        isActive: identical(_activeRoom, room),
        isBusy: _isBusy,
        onJoin: _joinRoomButtonCallback(room),
        onLeave: room.call == null ? null : () => _leaveRoom(room),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _JoiningOverlay(roomName: _activeRoom?.roomName ?? '');
    }

    final activeRoom = _activeRoom;
    final activeCall = activeRoom?.call;
    final canSwitch =
        activeRoom != null &&
        activeCall != null &&
        _otherRoom(activeRoom).call != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multicall Example'),
        centerTitle: true,
        leading: IconButton(
          onPressed: _isBusy ? null : _leaveAllRoomsAndExit,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          _buildRoomPane(_alphaRoom),
          const Divider(height: 1),
          _buildRoomPane(_betaRoom),
          if (activeRoom != null && activeCall != null)
            _CallControls(
              call: activeCall,
              activeRoomName: activeRoom.roomName,
              canSwitch: canSwitch,
              isBusy: _isBusy,
              onSwitchRoom: _switchRoom,
            ),
        ],
      ),
    );
  }

  VoidCallback? _joinRoomButtonCallback(_RoomSession room) {
    if (room.call != null || _isBusy) return null;

    return () async {
      final shouldBecomeActive = _activeRoom == null;

      _setBusy(true);
      try {
        final joined = await _joinRoom(
          room,
          mediaPreferences: shouldBecomeActive
              ? const _MediaPreferences.enabled()
              : const _MediaPreferences.disabled(),
        );

        if (!joined) return;

        if (shouldBecomeActive) {
          _setActiveRoom(room);
        }
        // Background joins are auto-suspended by the SDK because the client
        // is configured with `multiCallAudioPolicy: suspendIncoming`. The
        // previously-active room keeps focus; this room joins muted until
        // the user switches into it via _switchRoom.
      } finally {
        _setBusy(false);
      }
    };
  }
}

class _RoomSession {
  _RoomSession({required this.roomId, required this.roomName, this.call});

  final String roomId;
  final String roomName;
  Call? call;
  bool isJoining = false;
}

class _MediaPreferences {
  const _MediaPreferences({
    required this.microphoneEnabled,
    required this.cameraEnabled,
  });

  const _MediaPreferences.enabled()
    : microphoneEnabled = true,
      cameraEnabled = true;

  const _MediaPreferences.disabled()
    : microphoneEnabled = false,
      cameraEnabled = false;

  final bool microphoneEnabled;
  final bool cameraEnabled;
}

class _JoiningOverlay extends StatelessWidget {
  const _JoiningOverlay({required this.roomName});

  final String roomName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Joining $roomName...', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Preparing the split view',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomPane extends StatelessWidget {
  const _RoomPane({
    required this.room,
    required this.isActive,
    required this.isBusy,
    required this.onJoin,
    required this.onLeave,
  });

  final _RoomSession room;
  final bool isActive;
  final bool isBusy;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;

  String get _statusLabel {
    if (room.isJoining) return 'Joining';
    if (room.call == null) return 'Not joined';
    return isActive ? 'Active' : 'Waiting';
  }

  Color get _statusColor {
    if (room.isJoining) return Colors.orange;
    if (room.call == null) return Colors.white38;
    return isActive ? Colors.green : Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: isActive ? Colors.green : Colors.transparent,
            width: 4,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.meeting_room,
                  size: 18,
                  color: isActive ? theme.colorScheme.primary : Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.roomName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        room.roomId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoomStatusChip(label: _statusLabel, color: _statusColor),
                const SizedBox(width: 12),
                if (room.call == null)
                  FilledButton.tonalIcon(
                    onPressed: isBusy ? null : onJoin,
                    icon: const Icon(Icons.add_call),
                    label: const Text('Join'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : onLeave,
                    icon: const Icon(Icons.call_end),
                    label: const Text('Leave'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ColoredBox(
                  color: Colors.black,
                  child: _RoomPaneContent(room: room, isActive: isActive),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomPaneContent extends StatelessWidget {
  const _RoomPaneContent({required this.room, required this.isActive});

  final _RoomSession room;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final call = room.call;

    if (room.isJoining) {
      return const Center(child: CircularProgressIndicator());
    }

    if (call == null) {
      return _InactiveRoomPlaceholder(
        title: room.roomName,
        description:
            'Join this room to keep it visible in the split layout and make it available for switching.',
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: StreamLocalVideoTheme(
            data: const StreamLocalVideoThemeData(
              localVideoWidth: 80,
              localVideoHeight: 110,
              localVideoPadding: 12,
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
          left: 12,
          right: 12,
          bottom: 12,
          child: PartialCallStateBuilder(
            call: call,
            selector: (state) => state.status,
            builder: (context, status) => _PaneInfoBanner(
              text: _statusText(status: status, isActive: isActive),
            ),
          ),
        ),
      ],
    );
  }

  String _statusText({required CallStatus status, required bool isActive}) {
    if (status.isConnected) {
      return isActive
          ? 'This room is active. Call controls apply here.'
          : 'This room stays joined with local mic/camera off and playout muted locally.';
    }

    if (status.isFastReconnecting || status.isReconnecting) {
      return 'Reconnecting...';
    }

    if (status.isMigrating) {
      return 'Migrating connection...';
    }

    return 'Connecting...';
  }
}

class _InactiveRoomPlaceholder extends StatelessWidget {
  const _InactiveRoomPlaceholder({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeight = constraints.maxHeight < 160;

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isCompactHeight) ...[
                  Icon(
                    Icons.video_call_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: isCompactHeight ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaneInfoBanner extends StatelessWidget {
  const _PaneInfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _RoomStatusChip extends StatelessWidget {
  const _RoomStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CallControls extends StatelessWidget {
  const _CallControls({
    required this.call,
    required this.activeRoomName,
    required this.canSwitch,
    required this.isBusy,
    required this.onSwitchRoom,
  });

  final Call call;
  final String activeRoomName;
  final bool canSwitch;
  final bool isBusy;
  final VoidCallback onSwitchRoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Controls apply to $activeRoomName',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ControlButton(
                    call: call,
                    builder: (context, call) =>
                        ToggleMicrophoneOption(call: call),
                  ),
                  const SizedBox(width: 12),
                  _ControlButton(
                    call: call,
                    builder: (context, call) => ToggleCameraOption(call: call),
                  ),
                  const SizedBox(width: 12),
                  _ControlButton(
                    call: call,
                    builder: (context, call) => FlipCameraOption(call: call),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canSwitch && !isBusy ? onSwitchRoom : null,
                      icon: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.swap_horiz),
                      label: const Text('Switch room'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
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

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.call, required this.builder});

  final Call call;
  final Widget Function(BuildContext context, Call call) builder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 52, height: 52, child: builder(context, call));
  }
}
