import 'package:audio_room_with_chat_starter/screens/widgets/audio_room_actions.dart';
import 'package:audio_room_with_chat_starter/screens/widgets/chat_sheet.dart';
import 'package:flutter/material.dart';

/// Placeholder for the in-call audio room UI with chat.
class AudioRoomScreen extends StatelessWidget {
  const AudioRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    /// TODO: Join the call, show participants grid and chat bottom sheet.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Room'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            /// TODO: Leave call and pop.
            Navigator.of(context).maybePop();
          },
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            /// TODO: Show participants grid.
          ],
        ),
      ),
    );
  }
}
