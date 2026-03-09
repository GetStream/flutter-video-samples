import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_config.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.onLogout,
  });

  final String userId;
  final String userName;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isJoining = false;
  String? _joiningRoomId;

  Future<void> _joinRoom(String roomId, String roomName) async {
    if (_isJoining) return;
    setState(() {
      _isJoining = true;
      _joiningRoomId = roomId;
    });

    try {
      final call = StreamVideo.instance.makeCall(
        callType: StreamCallType.defaultType(),
        id: roomId,
      );
      await call.getOrCreate();

      if (mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => CallScreen(call: call, initialRoomId: roomId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to join room: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
          _joiningRoomId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multicall Example'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'logout') await widget.onLogout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Log out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserInfoCard(userName: widget.userName, userId: widget.userId),
              const SizedBox(height: 32),
              Text(
                'Call Rooms',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join either room to open the split-room experience. The '
                'second room can be joined from inside the call screen, while '
                'one shared set of controls stays attached to the active room.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 16),
              _RoomCard(
                roomName: AppConfig.roomAlphaName,
                roomId: AppConfig.roomAlphaId,
                icon: Icons.groups,
                color: theme.colorScheme.primary,
                isJoining:
                    _isJoining && _joiningRoomId == AppConfig.roomAlphaId,
                isDisabled: _isJoining,
                onJoin: () =>
                    _joinRoom(AppConfig.roomAlphaId, AppConfig.roomAlphaName),
              ),
              const SizedBox(height: 12),
              _RoomCard(
                roomName: AppConfig.roomBravoName,
                roomId: AppConfig.roomBravoId,
                icon: Icons.meeting_room,
                color: theme.colorScheme.tertiary,
                isJoining:
                    _isJoining && _joiningRoomId == AppConfig.roomBravoId,
                isDisabled: _isJoining,
                onJoin: () =>
                    _joinRoom(AppConfig.roomBravoId, AppConfig.roomBravoName),
              ),
              const SizedBox(height: 32),
              _HowItWorksCard(theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({required this.userName, required this.userId});

  final String userName;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                userName[0].toUpperCase(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName, style: theme.textTheme.titleMedium),
                  Text(
                    userId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.roomName,
    required this.roomId,
    required this.icon,
    required this.color,
    required this.isJoining,
    required this.isDisabled,
    required this.onJoin,
  });

  final String roomName;
  final String roomId;
  final IconData icon;
  final Color color;
  final bool isJoining;
  final bool isDisabled;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDisabled ? null : onJoin,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(roomName, style: theme.textTheme.titleMedium),
                    Text(
                      roomId,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              if (isJoining)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton.icon(
                  onPressed: isDisabled ? null : onJoin,
                  icon: const Icon(Icons.video_call, size: 20),
                  label: const Text('Join'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  'How it works',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _bulletPoint('Join Room Alpha on Device 1', theme),
            _bulletPoint('Join Room Alpha on Device 2', theme),
            _bulletPoint(
              'Join one room first, then use "Join second room" from the split '
              'view to keep both rooms visible at once',
              theme,
            ),
            _bulletPoint(
              'Use "Switch room" to move your active mic, camera, and audio '
              'playout focus between the two joined rooms',
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulletPoint(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white38,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
