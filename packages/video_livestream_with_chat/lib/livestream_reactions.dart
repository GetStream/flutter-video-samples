import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

/// The quick reactions this sample can send.
///
/// `type` is what the Video API stores and broadcasts; `emojiCode` is the
/// conventional shortcode, and `emoji` is what we actually draw.
enum LivestreamReaction {
  heart(type: 'heart', emojiCode: ':heart:', emoji: '❤️'),
  clap(type: 'clap', emojiCode: ':clap:', emoji: '👏');

  const LivestreamReaction({
    required this.type,
    required this.emojiCode,
    required this.emoji,
  });

  final String type;
  final String emojiCode;
  final String emoji;

  /// Resolves an incoming reaction event back to one of our reactions.
  static LivestreamReaction? fromType(String type) {
    for (final reaction in values) {
      if (reaction.type == type) return reaction;
    }
    return null;
  }
}

/// A round, translucent button that sends a call reaction.
class ReactionButton extends StatelessWidget {
  const ReactionButton({super.key, required this.call, required this.reaction});

  final Call call;
  final LivestreamReaction reaction;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => call.sendReaction(
        reactionType: reaction.type,
        emojiCode: reaction.emojiCode,
      ),
      icon: Text(reaction.emoji, style: const TextStyle(fontSize: 20)),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.16),
      ),
    );
  }
}

/// Renders reactions floating up over the video.
///
/// Reactions arrive as `StreamCallReactionEvent`s on [Call.callEvents] — the
/// coordinator broadcasts them to every participant, including whoever sent
/// them, so the sender sees their own reaction through the same path as
/// everyone else and there is nothing extra to wire up locally.
class FloatingReactionsLayer extends StatefulWidget {
  const FloatingReactionsLayer({super.key, required this.call});

  final Call call;

  @override
  State<FloatingReactionsLayer> createState() => _FloatingReactionsLayerState();
}

class _FloatingReactionsLayerState extends State<FloatingReactionsLayer> {
  static const _maxConcurrent = 24;

  StreamSubscription<void>? _subscription;
  final _random = Random();
  final List<_FloatingReaction> _reactions = [];
  int _nextId = 0;

  @override
  void initState() {
    super.initState();

    _subscription = widget.call.callEvents.on<StreamCallReactionEvent>((event) {
      final reaction = LivestreamReaction.fromType(event.reactionType);
      if (reaction == null || !mounted) return;

      setState(() {
        // Drop the oldest if a burst comes in, so a reaction storm can't grow
        // the widget tree without bound.
        if (_reactions.length >= _maxConcurrent) _reactions.removeAt(0);

        _reactions.add(
          _FloatingReaction(
            id: _nextId++,
            emoji: reaction.emoji,
            horizontalDrift: _random.nextDouble() * 2 - 1,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _reactions.removeWhere((r) => r.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final reaction in _reactions)
            Positioned(
              // Start just above the composer, on the side the reaction
              // buttons live, and rise from there.
              right: 24,
              bottom: MediaQuery.paddingOf(context).bottom + 72,
              child: _RisingEmoji(
                key: ValueKey(reaction.id),
                emoji: reaction.emoji,
                horizontalDrift: reaction.horizontalDrift,
                onCompleted: () => _remove(reaction.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingReaction {
  const _FloatingReaction({
    required this.id,
    required this.emoji,
    required this.horizontalDrift,
  });

  final int id;
  final String emoji;

  /// -1 to 1; keeps simultaneous reactions from stacking in a straight line.
  final double horizontalDrift;
}

/// One emoji drifting upwards and fading out.
class _RisingEmoji extends StatefulWidget {
  const _RisingEmoji({
    super.key,
    required this.emoji,
    required this.horizontalDrift,
    required this.onCompleted,
  });

  final String emoji;
  final double horizontalDrift;
  final VoidCallback onCompleted;

  @override
  State<_RisingEmoji> createState() => _RisingEmojiState();
}

class _RisingEmojiState extends State<_RisingEmoji>
    with SingleTickerProviderStateMixin {
  /// Point in the animation where the emoji starts fading out.
  static const _fadeStart = 0.7;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onCompleted);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final progress = curve.value;

        return Transform.translate(
          // Rise most of the screen height while swaying sideways.
          offset: Offset(
            widget.horizontalDrift * 28 * sin(progress * pi * 2),
            -progress * (MediaQuery.sizeOf(context).height * 0.45),
          ),
          child: Opacity(
            // Stay solid most of the way up, then fade over the last stretch.
            opacity: progress < _fadeStart
                ? 1
                : (1 - progress) / (1 - _fadeStart),
            child: Transform.scale(scale: 0.8 + progress * 0.4, child: child),
          ),
        );
      },
      child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
    );
  }
}
