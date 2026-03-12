// ignore_for_file: unused_element
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

class ChannelScreen extends StatelessWidget {
  const ChannelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    /// Add channel UI here.
    return SizedBox();
  }

  List<StreamAttachmentWidgetBuilder> _customAttachmentBuilders(
    Message message,
  ) {
    return StreamAttachmentWidgetBuilder.defaultBuilders(message: message);
  }

  /// Creates a new call and sends a message with its metadata to the chat.
  void _startCall(BuildContext context) async {
    /// TODO: Add code to start a call.
  }
}
