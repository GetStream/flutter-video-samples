import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' hide User;

/// A draggable bottom-sheet chat panel shown on top of an active video call.
///
/// Requires a [StreamChannel] ancestor to supply the channel.
class InCallChat extends StatelessWidget {
  const InCallChat({super.key, this.onClose});

  /// Called when the user taps the close button in the panel header.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'In-call chat',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Hide chat',
                      visualDensity: VisualDensity.compact,
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              const Expanded(child: StreamMessageListView()),
              const SafeArea(child: StreamMessageInput()),
            ],
          ),
        ),
      ),
    );
  }
}
