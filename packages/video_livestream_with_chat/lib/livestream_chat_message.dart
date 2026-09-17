import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'app_config.dart';

/// A single chat line rendered over the livestream.
///
/// Deliberately not a chat bubble: over video you want the smallest amount of
/// opaque surface possible, so this is just an avatar, a name and the text,
/// with a soft shadow to keep it readable on bright frames.
class LivestreamChatMessage extends StatelessWidget {
  const LivestreamChatMessage({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final user = message.user;
    if (user == null) return const SizedBox.shrink();

    final isHost = AppConfig.isHost(user.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamUserAvatar(
            user: user,
            showOnlineStatus: false,
            borderRadius: BorderRadius.circular(14),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _shadowed(
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 6),
                      const _CreatorBadge(),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      formatShortAge(message.createdAt),
                      style: _shadowed(
                        const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message.text ?? '',
                  style: _shadowed(
                    const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorBadge extends StatelessWidget {
  const _CreatorBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'CREATOR',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// A system message (someone joined, the channel was created, …).
class LivestreamSystemMessage extends StatelessWidget {
  const LivestreamSystemMessage({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        '${message.text ?? ''}  ${formatShortAge(message.createdAt)}',
        textAlign: TextAlign.center,
        style: _shadowed(const TextStyle(color: Colors.white54, fontSize: 11)),
      ),
    );
  }
}

/// Compact relative time, the way broadcast chats show it: `now`, `3m`, `2h`.
String formatShortAge(DateTime createdAt) {
  final age = DateTime.now().difference(createdAt.toLocal());

  if (age.inMinutes < 1) return 'now';
  if (age.inHours < 1) return '${age.inMinutes}m';
  if (age.inDays < 1) return '${age.inHours}h';
  return '${age.inDays}d';
}

/// Adds a drop shadow so light text stays legible over a bright video frame.
TextStyle _shadowed(TextStyle style) {
  return style.copyWith(
    shadows: const [
      Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
    ],
  );
}
