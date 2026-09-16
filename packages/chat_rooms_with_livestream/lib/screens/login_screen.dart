import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart' as video;

import '../env/env.dart';
import '../models/app_user.dart';
import '../rooms.dart';
import '../theme.dart';
import 'room_list_screen.dart';

/// Pick-a-user sign-in. This sample has no backend, so each sample user ships
/// with a pre-minted token; one JWT authenticates both Chat and Video.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _connectingUserId;
  String? _error;

  Future<void> _signIn(AppUser user) async {
    setState(() {
      _connectingUserId = user.id;
      _error = null;
    });

    try {
      final client = StreamChat.of(context).client;

      // Chat: one connected user at a time.
      await client.disconnectUser();
      await client.connectUser(
        User(id: user.id, name: user.name, image: user.image),
        user.token,
      );

      // Video: the singleton must be torn down before a new one is built.
      if (video.StreamVideo.isInitialized()) {
        await video.StreamVideo.reset(disconnect: true);
      }
      video.StreamVideo(
        Env.streamApiKey,
        user: video.User.regular(
          userId: user.id,
          name: user.name,
          image: user.image,
        ),
        userToken: user.token,
      );

      // The rooms are predefined in code and materialised on Stream the
      // first time anyone signs in.
      await ensureRoomsExist(client);

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RoomListScreen(user: user)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _connectingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creators = sampleUsers.where((u) => u.role == AppRole.creator);
    final members = sampleUsers.where((u) => u.role == AppRole.member);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.sensors_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Creator Rooms',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Chat rooms that go live',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.live.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.live.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.live, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 20),
            ],
            _sectionLabel('Sign in as a creator'),
            const SizedBox(height: 4),
            const Text(
              'Creators can start a livestream from inside any room.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            for (final user in creators) _userTile(user),
            const SizedBox(height: 28),
            _sectionLabel('Sign in as a member'),
            const SizedBox(height: 4),
            const Text(
              'Members chat in every room and watch whatever goes live.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            for (final user in members) _userTile(user),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      color: AppColors.primary,
    ),
  );

  Widget _userTile(AppUser user) {
    final isCreator = user.role == AppRole.creator;
    final busy = _connectingUserId != null;
    final connecting = _connectingUserId == user.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.outline),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          onTap: busy ? null : () => _signIn(user),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surfaceHigh,
            backgroundImage: NetworkImage(user.image),
          ),
          title: Text(
            user.name,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isCreator
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    user.role.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: isCreator
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          trailing: connecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
        ),
      ),
    );
  }
}
