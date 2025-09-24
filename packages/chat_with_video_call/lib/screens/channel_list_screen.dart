import 'package:chat_with_video_call/app_config.dart';
import 'package:chat_with_video_call/sample_user.dart';
import 'package:chat_with_video_call/screens/channel_screen.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

class ChannelListScreen extends StatefulWidget {
  const ChannelListScreen({Key? key, required this.onLogout}) : super(key: key);

  final VoidCallback onLogout;

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  late final _listController = StreamChannelListController(
    client: StreamChat.of(context).client,
    filter: Filter.in_(
      'members',
      [StreamChat.of(context).currentUser!.id],
    ),
    channelStateSort: const [SortOption.desc('last_message_at')],
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StreamChannelListHeader(
        titleBuilder: (context, status, client) {
          return Text(
            "Chat with Video",
            style: StreamChatTheme.of(context).textTheme.headlineBold,
          );
        },
        actions: [
          IconButton(
            icon: const Icon(
              color: Colors.black,
              Icons.logout,
            ),
            onPressed: () async => widget.onLogout.call(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final channel = StreamChat.of(context).client.channel(
            "messaging",
            extraData: {
              "members": sampleUsers.map((user) => user.id).toList(),
            },
          );

          await channel.create();
          _navigateToChannel(channel);
        },
        child: const Icon(Icons.add),
      ),
      body: StreamChannelListView(
        controller: _listController,
        onChannelTap: _navigateToChannel,
      ),
    );
  }

  void _navigateToChannel(Channel channel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return StreamChannel(
            channel: channel,
            child: ChannelScreen(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }
}
