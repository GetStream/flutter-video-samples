import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart' as video;

import '../models/app_user.dart';
import '../models/live_session.dart';
import '../models/room.dart';
import '../theme.dart';
import '../widgets/live_badge.dart';
import 'room_screen.dart';

/// The lobby: every predefined room, with a LIVE flag on whichever one is
/// currently broadcasting.
class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  late final _controller = StreamChannelListController(
    client: StreamChat.of(context).client,
    // Rooms are public, so they are queried by id rather than by membership.
    filter: Filter.and([
      Filter.equal('type', roomChannelType),
      Filter.in_('id', [for (final room in predefinedRooms) room.id]),
    ]),
    channelStateSort: const [SortOption.desc('last_message_at')],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await StreamChat.of(context).client.disconnectUser();
    if (video.StreamVideo.isInitialized()) {
      await video.StreamVideo.reset(disconnect: true);
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creator Rooms',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            Text(
              'Chat rooms that go live',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(child: _roleChip()),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.surfaceHigh,
              backgroundImage: NetworkImage(widget.user.image),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: _BenchmarkRoomCard(user: widget.user),
          ),
          Expanded(child: _roomList()),
        ],
      ),
    );
  }

  Widget _roomList() {
    return StreamChannelListView(
      controller: _controller,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      separatorBuilder: (_, _, _) => const SizedBox(height: 10),
      emptyBuilder: (_) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No rooms found.\nSign out and back in to set them up.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ),
      errorBuilder: (_, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.live),
          ),
        ),
      ),
      itemBuilder: (context, channels, index, _) =>
          _RoomCard(channel: channels[index], user: widget.user),
    );
  }

  Widget _roleChip() {
    final isCreator = widget.user.role == AppRole.creator;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isCreator
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        widget.user.role.label.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: isCreator ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.channel, required this.user});

  final Channel channel;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final room = roomForChannelId(channel.id);
    final accent = room?.accent ?? AppColors.primary;

    // The live pointer lives in the channel's custom data, so it updates for
    // every member the moment the host writes it.
    return StreamBuilder<LiveSession?>(
      stream: liveSessionStream(channel),
      initialData: currentLiveSession(channel),
      builder: (context, snapshot) {
        final session = snapshot.data;
        final isLive = session != null;

        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StreamChannel(
                  channel: channel,
                  child: RoomScreen(user: user),
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLive
                      ? AppColors.live.withValues(alpha: 0.7)
                      : AppColors.outline,
                  width: isLive ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      room?.emoji ?? '💬',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                room?.name ?? channel.name ?? 'Room',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            if (isLive) ...[
                              const SizedBox(width: 8),
                              const LiveBadge(compact: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isLive
                              ? '${session.hostName} · ${session.title}'
                              : room?.topic ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isLive
                                ? AppColors.live
                                : AppColors.textMuted,
                            fontWeight: isLive
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _LastMessageLine(channel: channel),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  StreamUnreadIndicator.channels(cid: channel.cid),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Entry point to the backend-run benchmark room, pinned above the regular
/// rooms: paste the call id the backend hands out and open the room.
///
/// The room's chat channel is `livestream:<callId>`, so the backend can post
/// into it with the same id it created the call with. Opening it creates the
/// channel if the backend has not.
class _BenchmarkRoomCard extends StatefulWidget {
  const _BenchmarkRoomCard({required this.user});

  final AppUser user;

  @override
  State<_BenchmarkRoomCard> createState() => _BenchmarkRoomCardState();
}

class _BenchmarkRoomCardState extends State<_BenchmarkRoomCard> {
  /// What Stream accepts as a chat channel id.
  static final _validId = RegExp(r'^[a-zA-Z0-9_-]+$');

  late final _controller = TextEditingController(text: backendCallId.value);
  bool _opening = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _controller.text = text;
  }

  Future<void> _open() async {
    final callId = _controller.text.trim();
    if (callId.isEmpty) {
      return _snack('Paste the call id from the backend first.');
    }
    if (!_validId.hasMatch(callId)) {
      return _snack(
        'The call id doubles as the chat channel id, which only allows '
        'letters, digits, "-" and "_".',
      );
    }

    final room = benchmarkRoomFor(callId);
    final channel = StreamChat.of(context).client.channel(
      roomChannelType,
      id: callId,
      extraData: {'name': room.name, 'topic': room.topic},
    );

    setState(() => _opening = true);
    try {
      backendCallId.value = callId;
      await channel.watch();
    } on StreamChatError catch (e) {
      // Usually the `user` role missing Create Channel on the room type.
      return _snack('Could not open the room: ${e.message}');
    } finally {
      if (mounted) setState(() => _opening = false);
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StreamChannel(
          channel: channel,
          child: RoomScreen(user: widget.user),
        ),
      ),
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final room = benchmarkRoomFor('');
    final accent = room.accent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                alignment: Alignment.center,
                child: Text(room.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Chat and video share the call id',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_opening,
                  autocorrect: false,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _open(),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Call id from the backend',
                    suffixIcon: IconButton(
                      tooltip: 'Paste',
                      onPressed: _opening ? null : _paste,
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _opening ? null : _open,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _opening
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Open room'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A compact "who said what last" line under the room topic.
class _LastMessageLine extends StatelessWidget {
  const _LastMessageLine({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Message>>(
      stream: channel.state?.messagesStream,
      initialData: channel.state?.messages,
      builder: (context, snapshot) {
        final last = snapshot.data?.lastOrNull;
        if (last == null) {
          return const Text(
            'No messages yet',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          );
        }

        final preview =
            last.attachments.any((a) => a.type == livestreamAttachmentType)
            ? 'started a livestream'
            : last.text ?? '';

        return Text(
          '${last.user?.name ?? 'Someone'}: $preview',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        );
      },
    );
  }
}
