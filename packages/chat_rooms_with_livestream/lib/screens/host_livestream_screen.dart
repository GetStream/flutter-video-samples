import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as chat;
import 'package:stream_video_flutter/stream_video_flutter.dart';

import '../live_announcements.dart';
import '../models/app_user.dart';
import '../models/live_session.dart';
import '../models/room.dart';
import '../theme.dart';
import '../widgets/live_badge.dart';

/// The creator's broadcast screen.
///
/// Lifecycle: `getOrCreate` (marking the creator as `host` so the server grants
/// backstage access) -> `join` with camera and mic on -> backstage preview ->
/// `goLive` -> `stopLive` + `end` + `leave`.
///
/// Going live also posts an announcement into the room's conversation. That
/// message is what turns a plain Stream Video livestream into "a livestream
/// inside a chat room": it renders as a join card, and every live indicator in
/// the app reads its state from it. Ending the stream edits the same message.
class HostLivestreamScreen extends StatefulWidget {
  const HostLivestreamScreen({
    super.key,
    required this.channel,
    required this.user,
    required this.title,
    required this.room,
  });

  final chat.Channel channel;
  final AppUser user;
  final String title;
  final RoomDefinition? room;

  @override
  State<HostLivestreamScreen> createState() => _HostLivestreamScreenState();
}

class _HostLivestreamScreenState extends State<HostLivestreamScreen> {
  late final String _callId = newLiveCallId(widget.channel.id!);

  Call? _call;
  bool _joined = false;
  bool _withCamera = true;
  bool _withMicrophone = true;
  bool _busy = false;
  bool _announced = false;
  chat.Message? _announcement;
  LiveSession? _session;
  bool _showChat = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestDevicesThenJoin();
  }

  Future<void> _requestDevicesThenJoin() async {
    final statuses = await [Permission.camera, Permission.microphone].request();

    if (!mounted) return;
    setState(() {
      _withCamera = statuses[Permission.camera]?.isGranted ?? false;
      _withMicrophone = statuses[Permission.microphone]?.isGranted ?? false;
    });

    await _joinAsHost();
  }

  @override
  void dispose() {
    // Safety net for a pop that bypassed "End stream": take the room back out
    // of its live state, then release the call.
    if (_announced) unawaited(_markAnnouncementEnded());
    unawaited(_call?.leave());
    super.dispose();
  }

  Future<Result<None>> _join(
    Call call, {
    required bool withCamera,
    required bool withMicrophone,
  }) => call.join(
    connectOptions: CallConnectOptions(
      camera: withCamera ? TrackOption.enabled() : TrackOption.disabled(),
      microphone: withMicrophone
          ? TrackOption.enabled()
          : TrackOption.disabled(),
    ),
  );

  Future<void> _joinAsHost() async {
    final call = StreamVideo.instance.makeCall(
      callType: StreamCallType.liveStream(),
      id: _callId,
    );

    final created = await call.getOrCreate(
      // The `host` role is what grants join-backstage on the livestream call
      // type, so the creator can set up before anyone can watch.
      members: [MemberRequest(userId: widget.user.id, role: 'host')],
    );

    await created.fold(
      success: (_) async {
        var joined = await _join(
          call,
          withCamera: _withCamera,
          withMicrophone: _withMicrophone,
        );

        joined.fold(
          success: (_) {
            if (mounted) {
              setState(() {
                _call = call;
                _joined = true;
              });
            }
          },
          failure: (f) {
            if (mounted) setState(() => _error = f.error.message);
          },
        );
      },
      failure: (f) async {
        if (mounted) setState(() => _error = f.error.message);
      },
    );
  }

  Future<void> _goLive() async {
    final call = _call;
    if (call == null) return;
    setState(() => _busy = true);

    final result = await call.goLive();

    await result.fold(
      success: (_) async {
        final session = LiveSession(
          callId: _callId,
          hostId: widget.user.id,
          hostName: widget.user.name,
          title: widget.title,
          startedAt: DateTime.now().toUtc(),
        );
        await _announce(session);
        if (mounted) setState(() => _announced = true);
      },
      failure: (f) async {
        if (mounted) _snack('Could not go live: ${f.error.message}');
      },
    );

    if (mounted) setState(() => _busy = false);
  }

  /// Announces the broadcast in the room. This single message is what makes the
  /// room live: the join card, the room banner and the lobby's LIVE badge all
  /// read their state from it.
  ///
  /// See `live_announcements.dart` - the chat side of the stream lifecycle lives
  /// there, together with why a production app should drive it from the backend
  /// instead of from here.
  Future<void> _announce(LiveSession session) async {
    _announcement = await postLiveAnnouncement(
      channel: widget.channel,
      session: session,
      hostName: widget.user.name,
    );
    _session = session;
  }

  /// Flips every surface back out of its live state.
  ///
  /// Best effort, and only as reliable as this app staying alive - a crash, a
  /// force-quit or a dropped network here leaves the room advertising a stream
  /// that has already stopped. `live_announcements.dart` explains the webhook
  /// driven fix.
  Future<void> _markAnnouncementEnded() async {
    final announcement = _announcement;
    final session = _session;
    if (announcement == null || session == null) return;

    await markLiveAnnouncementEnded(
      channel: widget.channel,
      announcement: announcement,
      session: session,
    );
  }

  Future<void> _endStream() async {
    final call = _call;
    if (call == null) return;
    setState(() => _busy = true);

    await _markAnnouncementEnded();
    _announced = false;

    await call.stopLive();
    await call.end();
    await call.leave();

    if (mounted) {
      setState(() => _busy = false);
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmLeave(bool isLive) async {
    if (!isLive) return true;

    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('End the stream?', style: TextStyle(fontSize: 18)),
        content: Text(
          'Leaving ends the broadcast for everyone watching in '
          '${widget.room?.name ?? 'this room'}.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep streaming'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.live,
              foregroundColor: Colors.white,
            ),
            child: const Text('End stream'),
          ),
        ],
      ),
    );

    return leave ?? false;
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _errorScaffold(_error!);
    final call = _call;
    if (!_joined || call == null) return _loadingScaffold();

    // List every call value used in the overlay here for efficient state updates.
    return PartialCallStateBuilder<
      ({bool isBackstage, int viewerCount, bool cameraOn, bool micOn})
    >(
      call: call,
      selector: (state) => (
        isBackstage: state.isBackstage,
        viewerCount: state.otherParticipants.length,
        cameraOn: state.localParticipant?.isVideoEnabled ?? false,
        micOn: state.localParticipant?.isAudioEnabled ?? false,
      ),
      builder: (context, data) {
        // Live status is derived from backstage - never a separate bool.
        final isLive = !data.isBackstage;
        final local = call.state.value.localParticipant;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (isLive) {
              if (await _confirmLeave(true)) await _endStream();
              return;
            }
            final navigator = Navigator.of(context);
            await call.leave();
            if (mounted) navigator.pop();
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (local != null && data.cameraOn)
                  StreamVideoRenderer(
                    call: call,
                    participant: local,
                    videoTrackType: SfuTrackType.video,
                    videoFit: VideoFit.cover,
                  )
                else
                  const _AudioOnlyBackdrop(),

                const _ControlsShade(),

                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 12,
                  right: 12,
                  child: _topBar(isLive, data.viewerCount),
                ),

                if (_showChat)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    top: MediaQuery.of(context).size.height * 0.4,
                    child: _chatPanel(),
                  ),

                if (!_showChat)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                    child: _controlBar(
                      isLive,
                      micOn: data.micOn,
                      cameraOn: data.cameraOn,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(bool isLive, int viewerCount) {
    return Row(
      children: [
        _circleButton(
          icon: Icons.close_rounded,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isLive)
                    LiveBadge(viewerCount: viewerCount)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'BACKSTAGE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${widget.room?.emoji ?? ''} ${widget.room?.name ?? 'Room'}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        _circleButton(
          icon: _showChat
              ? Icons.chat_bubble_rounded
              : Icons.chat_bubble_outline_rounded,
          highlighted: _showChat,
          onTap: () => setState(() => _showChat = !_showChat),
        ),
      ],
    );
  }

  /// Takes its values from the selector rather than reading `call.state.value`
  /// itself - see the note on the builder above.
  Widget _controlBar(
    bool isLive, {
    required bool micOn,
    required bool cameraOn,
  }) {
    return Row(
      children: [
        _circleButton(
          icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
          danger: !micOn,
          onTap: () => _call?.setMicrophoneEnabled(enabled: !micOn),
        ),
        const SizedBox(width: 12),
        _circleButton(
          icon: cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
          danger: !cameraOn,
          onTap: () => _call?.setCameraEnabled(enabled: !cameraOn),
        ),
        const SizedBox(width: 12),
        _circleButton(
          icon: Icons.flip_camera_ios_rounded,
          onTap: () => _call?.flipCamera(),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: _busy ? null : (isLive ? _endStream : _goLive),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  isLive ? Icons.stop_rounded : Icons.sensors_rounded,
                  size: 20,
                ),
          label: Text(isLive ? 'End stream' : 'Go live'),
          style: FilledButton.styleFrom(
            backgroundColor: isLive
                ? Colors.white.withValues(alpha: 0.22)
                : AppColors.live,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
        ),
      ],
    );
  }

  /// The room's conversation, over the camera preview, so the creator can read
  /// and answer chat without leaving the broadcast.
  Widget _chatPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: ColoredBox(
        color: AppColors.background,
        child: chat.StreamChannel(
          channel: widget.channel,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.outline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.room?.emoji ?? '💬'}  ${widget.room?.name ?? 'Room'} chat',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _showChat = false),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: chat.StreamMessageListView()),
              chat.StreamMessageComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool danger = false,
    bool highlighted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: danger
              ? AppColors.live.withValues(alpha: 0.85)
              : highlighted
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }

  Widget _loadingScaffold() => const Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Setting up backstage…',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );

  Widget _errorScaffold(String message) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.live,
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to the room'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Stand-in for the camera preview while the creator's camera is off - either
/// toggled off mid-stream or never available on this device.
class _AudioOnlyBackdrop extends StatelessWidget {
  const _AudioOnlyBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241A33), Colors.black],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq_rounded, color: Colors.white38, size: 44),
            SizedBox(height: 12),
            Text(
              'Audio only',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Camera is off',
              style: TextStyle(color: Colors.white38, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Darkens the top and bottom edges of the camera preview so the white text and
/// icons layered over it stay readable against any background.
class _ControlsShade extends StatelessWidget {
  const _ControlsShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.65),
            ],
            stops: const [0, 0.25, 0.65, 1],
          ),
        ),
      ),
    );
  }
}
