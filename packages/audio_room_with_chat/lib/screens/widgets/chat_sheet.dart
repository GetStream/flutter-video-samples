import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

class ChatSheet extends StatelessWidget {
  const ChatSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 280,
        child: Column(
          children: <Widget>[
            Expanded(
              child: StreamMessageListView(),
            ),
            SafeArea(child: StreamMessageInput()),
          ],
        ),
      ),
    );
  }
}
