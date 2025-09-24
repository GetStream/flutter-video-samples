import 'package:audio_room_with_chat/screens/audio_room_screen.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class AudioRoomsScreen extends StatefulWidget {
  const AudioRoomsScreen({
    super.key,
    required this.onLogoutPressed,
  });

  final VoidCallback onLogoutPressed;

  @override
  State<AudioRoomsScreen> createState() => _AudioRoomsScreenState();
}

class _AudioRoomsScreenState extends State<AudioRoomsScreen> {
  late Future<QueriedCalls> _roomsFuture;

  @override
  void initState() {
    super.initState();
    _roomsFuture = fetchAudioRooms();
  }

  void _reloadRooms() {
    setState(() {
      _roomsFuture = fetchAudioRooms();
    });
  }

  Future<QueriedCalls> fetchAudioRooms() async {
    final result = await StreamVideo.instance.queryCalls(
      filterConditions: {
        "type": 'audio_room',
        "live": true,
      },
    );

    return result.getDataOrNull() ?? QueriedCalls(calls: []);
  }

  Future<Call> createAudioRoom() async {
    final call = StreamVideo.instance.makeCall(
      id: 'audio_room_${DateTime.now().millisecondsSinceEpoch}',
      callType: StreamCallType.audioRoom(),
    );

    await call.getOrCreate(
      custom: {
        'name': 'Audio Room ${DateTime.now().millisecondsSinceEpoch}',
      },
    );

    return call;
  }

  Future<Channel> createChatChannel(
    Call call, {
    bool create = false,
  }) async {
    final channel = StreamChat.of(context).client.channel(
      "livestream",
      id: call.callCid.id,
    );

    if (create) {
      await channel.create();
    }

    await channel.watch();
    return channel;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Rooms'),
        actions: [
          IconButton(
            onPressed: widget.onLogoutPressed,
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<QueriedCalls>(
        future: _roomsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: _reloadRooms, error: snapshot.error);
          }

          final calls = snapshot.data?.calls;
          if (calls == null || calls.isEmpty) {
            return _EmptyState(onRefresh: _reloadRooms);
          }

          return RefreshIndicator(
            onRefresh: () async => _reloadRooms(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: calls.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final call = calls[index].call;
                final name =
                    (call.details.custom['name'] as String?) ??
                    'Audio Room ${index + 1}';

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.mic_none)),
                  title: Text(name),
                  onTap: () => _joinCall(call.cid),
                  trailing: TextButton.icon(
                    onPressed: () => _joinCall(call.cid),
                    icon: const Icon(Icons.meeting_room_outlined),
                    label: const Text('Join'),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onCreatePressed,
        icon: const Icon(Icons.add_call),
        label: const Text('New room'),
      ),
    );
  }

  Future<void> _onCreatePressed() async {
    final call = await createAudioRoom();
    final channel = await createChatChannel(call, create: true);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AudioRoomScreen(
          audioRoomCall: call,
          chatChannel: channel,
        ),
      ),
    );

    if (!mounted) return;
    _reloadRooms();
  }

  Future<void> _joinCall(StreamCallCid callCid) async {
    final call = StreamVideo.instance.makeCall(
      callType: callCid.type,
      id: callCid.id,
    );

    await call.getOrCreate();
    final channel = await createChatChannel(call);

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AudioRoomScreen(
          audioRoomCall: call,
          chatChannel: channel,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.spatial_audio_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          const Text('No audio rooms yet'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh audio rooms'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, this.error});

  final VoidCallback onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text('Failed to load audio rooms'),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
