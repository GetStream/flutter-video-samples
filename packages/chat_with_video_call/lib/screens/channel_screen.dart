import 'dart:math';

import 'package:chat_with_video_call/screens/attachment/call_attachment_builder.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class ChannelScreen extends StatelessWidget {
  const ChannelScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StreamChannelHeader(
        actions: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.call_rounded,
              color: Colors.black,
            ),
            onPressed: () async => _startCall(context),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamMessageListView(
              messageBuilder: (context, details, messages, defaultMessage) {
                return defaultMessage.copyWith(
                  attachmentBuilders: _customAttachmentBuilders(
                    defaultMessage.message,
                  ),
                );
              },
            ),
          ),
          StreamMessageInput(),
        ],
      ),
    );
  }

  List<StreamAttachmentWidgetBuilder> _customAttachmentBuilders(
    Message message,
  ) {
    return [
      CallAttachmentWidgetBuilder(),
      ...StreamAttachmentWidgetBuilder.defaultBuilders(message: message),
    ];
  }

  /// Creates a new call and sends a message with its metadata to the chat.
  void _startCall(BuildContext context) async {
    final currentUser = StreamChat.of(context).currentUser;
    final channel = StreamChannel.of(context).channel;

    final call = StreamVideo.instance.makeCall(
      id: '${channel.id}_call${Random().nextInt(10000)}',
      callType: StreamCallType.defaultType(),
    );

    await call.getOrCreate();

    channel.sendMessage(
      Message(
        attachments: [
          Attachment(
            type: "custom",
            authorName: currentUser?.name ?? "",
            uploadState: UploadState.success(),
            extraData: {
              "callId": call.id,
              "callType": call.type.toString(),
            },
          ),
        ],
      ),
    );
  }
}
