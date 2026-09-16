import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart' as video;

import '../models/app_user.dart';
import '../models/live_session.dart';
import '../models/room.dart';
import '../theme.dart';
import '../widgets/live_badge.dart';
import '../widgets/live_watch_scope.dart';
import 'host_livestream_screen.dart';
import 'thread_screen.dart';

/// A single chat room. Members chat here; creators can also start a livestream
/// that everyone in the room can watch **without leaving the conversation**.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _composerController = StreamMessageComposerController();
  final _focusNode = FocusNode();

  /// The livestream expanded inline right now, if any.
  video.Call? _watchCall;
  bool _joining = false;
  bool _fullscreen = false;

  @override
  void dispose() {
    // Leaving the room leaves the stream.
    unawaited(_watchCall?.leave());
    _composerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Expands the banner into the inline player.
  Future<void> _watch(LiveSession session) async {
    if (_joining || _watchCall?.id == session.callId) return;
    setState(() => _joining = true);

    final call = video.StreamVideo.instance.makeCall(
      callType: video.StreamCallType.liveStream(),
      id: session.callId,
    );
    final result = await call.getOrCreate();

    if (!mounted) return;
    result.fold(
      success: (_) => setState(() {
        _watchCall = call;
        _joining = false;
      }),
      failure: (f) {
        setState(() => _joining = false);
        _snack('Could not open the stream: ${f.error.message}');
      },
    );
  }

  /// Collapses the player back to the banner and disconnects from the call.
  Future<void> _stopWatching() async {
    final call = _watchCall;
    if (call == null) return;

    setState(() {
      _watchCall = null;
      _fullscreen = false;
    });
    await call.leave();
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _startLivestream(Channel channel, RoomDefinition? room) async {
    final title = await _askForTitle(room);
    if (title == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HostLivestreamScreen(
          channel: channel,
          user: widget.user,
          title: title,
          room: room,
        ),
      ),
    );
  }

  Future<String?> _askForTitle(RoomDefinition? room) {
    final controller = TextEditingController(
      text:
          '${widget.user.name.split(' ').first} live in ${room?.name ?? 'the room'}',
    );

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('Go live', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Stream title',
            helperText: 'Shown in the room and on the join card.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(dialogContext).pop(text.isEmpty ? 'Live now' : text);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.live,
              foregroundColor: Colors.white,
            ),
            child: const Text('Set up stream'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channel = StreamChannel.of(context).channel;
    final room = roomForChannelId(channel.id);
    final accent = room?.accent ?? AppColors.primary;

    return StreamBuilder<LiveSession?>(
      stream: liveSessionStream(channel),
      initialData: currentLiveSession(channel),
      builder: (context, snapshot) {
        final session = snapshot.data;
        final someoneElseIsLive =
            session != null && session.hostId != widget.user.id;

        // The stream ending while it is expanded collapses it automatically.
        if (session == null && _watchCall != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _stopWatching());
        }

        final watching = _watchCall != null;

        if (_fullscreen && watching) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) setState(() => _fullscreen = false);
            },
            child: Scaffold(
              backgroundColor: Colors.black,
              body: _livePlayer(session),
            ),
          );
        }

        return LiveWatchScope(
          watch: _watch,
          watchedCallId: _watchCall?.id,
          child: Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      room?.emoji ?? '💬',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room?.name ?? channel.name ?? 'Room',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          room?.topic ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (widget.user.role.canGoLive)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilledButton.icon(
                      onPressed: someoneElseIsLive
                          ? null
                          : () => _startLivestream(channel, room),
                      icon: const Icon(Icons.sensors_rounded, size: 18),
                      label: const Text('Go live'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.live,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _liveArea(session),
                ),
                Expanded(
                  child: StreamMessageListView(
                    config: const StreamMessageListViewConfiguration(
                      swipeToReply: true,
                      markReadWhenAtTheBottom: true,
                    ),
                    onReplyTap: _quote,
                    threadBuilder: (_, parent) => ThreadScreen(parent: parent!),
                    builders: StreamMessageListViewBuilders(
                      empty: (_) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                room?.emoji ?? '💬',
                                style: const TextStyle(fontSize: 34),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                room?.topic ?? 'Start the conversation',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                StreamMessageComposer(
                  messageComposerController: _composerController,
                  focusNode: _focusNode,
                  onQuotedMessageCleared:
                      _composerController.clearQuotedMessage,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The strip above the message list: nothing when no one is live, the banner
  /// when someone is, and the docked player once the viewer expands it.
  Widget _liveArea(LiveSession? session) {
    if (session == null) return const SizedBox.shrink();

    final isHost = session.hostId == widget.user.id;
    if (_watchCall == null) {
      return _LiveBanner(
        session: session,
        isHost: isHost,
        busy: _joining,
        onWatch: () => _watch(session),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: _livePlayer(session)),
        _watchingBar(session),
      ],
    );
  }

  /// Slim control row under the docked player.
  Widget _watchingBar(LiveSession session) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.live, width: 1.5)),
      ),
      child: Row(
        children: [
          const LiveBadge(compact: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${session.hostName} · ${session.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _stopWatching,
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
            label: const Text('Leave stream'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.live,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _livePlayer(LiveSession? session) {
    final call = _watchCall;
    if (call == null) return const SizedBox.shrink();

    return video.LivestreamPlayer(
      call: call,
      // Passing onFullscreenTapped replaces the player's own fullscreen
      // handling outright, so this screen owns the state - including the
      // contain -> cover switch the player would otherwise make itself.
      onFullscreenTapped: () => setState(() => _fullscreen = !_fullscreen),
      videoFit: _fullscreen ? video.VideoFit.cover : video.VideoFit.contain,
      // Docked, the bar underneath carries the leave control; fullscreen hides
      // that bar, so the player's own slot provides one.
      backButtonBuilder: (_) => _fullscreen
          ? IconButton(
              tooltip: 'Leave stream',
              onPressed: _stopWatching,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.45),
              ),
            )
          : const SizedBox.shrink(),
      livestreamBackstageWidgetBuilder: (_, _) => const _WaitingForHost(),
      onCallDisconnected: (_) => _stopWatching(),
    );
  }

  void _quote(Message message) {
    _composerController.quotedMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }
}

/// Sticky "someone is live in this room" bar above the message list.
class _LiveBanner extends StatelessWidget {
  const _LiveBanner({
    required this.session,
    required this.isHost,
    required this.busy,
    required this.onWatch,
  });

  final LiveSession session;
  final bool isHost;
  final bool busy;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.live.withValues(alpha: 0.12),
      child: InkWell(
        onTap: isHost || busy ? null : onWatch,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.live, width: 1.5),
            ),
          ),
          child: Row(
            children: [
              const LiveBadge(compact: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      isHost
                          ? "You're broadcasting to this room"
                          : '${session.hostName} is live in this room',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isHost)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.live,
                          ),
                        )
                      : const Icon(
                          Icons.play_circle_fill_rounded,
                          color: AppColors.live,
                          size: 30,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingForHost extends StatelessWidget {
  const _WaitingForHost();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_rounded, color: Colors.white54, size: 30),
            SizedBox(height: 10),
            Text(
              'Waiting for the creator to go live…',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
