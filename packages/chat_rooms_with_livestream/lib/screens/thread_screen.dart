import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Replies to a single message. Reached from the room's message list.
class ThreadScreen extends StatelessWidget {
  const ThreadScreen({super.key, required this.parent});

  final Message parent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StreamThreadHeader(parent: parent),
      body: Column(
        children: [
          Expanded(child: StreamMessageListView(parentMessage: parent)),
          StreamMessageComposer(
            messageComposerController: StreamMessageComposerController(
              message: Message(parentId: parent.id),
            ),
          ),
        ],
      ),
    );
  }
}
