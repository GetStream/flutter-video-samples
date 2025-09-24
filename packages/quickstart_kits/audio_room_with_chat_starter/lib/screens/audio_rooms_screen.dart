import 'package:audio_room_with_chat_starter/screens/audio_room_screen.dart';
import 'package:flutter/material.dart';

/// Displays the list of audio rooms and allows creating/joining one.
class AudioRoomsScreen extends StatefulWidget {
  const AudioRoomsScreen({super.key, required this.onLogoutPressed});

  final VoidCallback onLogoutPressed;

  @override
  State<AudioRoomsScreen> createState() => _AudioRoomsScreenState();
}

class _AudioRoomsScreenState extends State<AudioRoomsScreen> {
  void _reloadRooms() {
    /// TODO: Implement audio rooms querying and reloading.
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
      body: FutureBuilder(
        /// TODO: Replace with actual future fetching audio rooms.
        future: Future.value(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: _reloadRooms, error: snapshot.error);
          }

          final calls = [];
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
                  onTap: () => _joinCall(),
                  trailing: TextButton.icon(
                    onPressed: () => _joinCall(),
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
    /// TODO: Create audio room call and its chat channel, then navigate.
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AudioRoomScreen(),
      ),
    );
  }

  Future<void> _joinCall() async {
    /// TODO: Join selected call and navigate to AudioRoomScreen.
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AudioRoomScreen(),
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
