import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' hide User;

/// A draggable bottom-sheet chat panel shown on top of an active video call.
///
/// Requires a [StreamChannel] ancestor to supply the channel.
class InCallChat extends StatelessWidget {
  const InCallChat({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 300,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                ],
              ),
            ),
            const Expanded(child: StreamMessageListView()),
            const SafeArea(child: StreamMessageInput()),
          ],
        ),
      ),
    );
  }
}
