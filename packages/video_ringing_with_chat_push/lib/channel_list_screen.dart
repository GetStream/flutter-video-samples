import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide User, CurrentPlatform;

import 'app_config.dart';
import 'channel_screen.dart';

class ChannelListScreen extends StatefulWidget {
  const ChannelListScreen({super.key, this.onLogout});

  final Future<void> Function()? onLogout;

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  late final _listController = StreamChannelListController(
    client: StreamChat.of(context).client,
    filter: Filter.in_('members', [StreamChat.of(context).currentUser!.id]),
    channelStateSort: const [SortOption.desc('last_message_at')],
  );

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _startNewChat() async {
    final client = StreamChat.of(context).client;
    final channel = client.channel(
      'messaging',
      extraData: {
        'members': [AppConfig.user1Id, AppConfig.user2Id],
      },
    );

    await channel.watch();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              StreamChannel(channel: channel, child: const ChannelScreen()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        centerTitle: true,
        actions: [
          if (widget.onLogout != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'logout') await widget.onLogout!();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Log out'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewChat,
        child: const Icon(Icons.edit),
      ),
      body: StreamChannelListView(
        controller: _listController,
        onChannelTap: (channel) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StreamChannel(channel: channel, child: const ChannelScreen()),
          ),
        ),
      ),
    );
  }
}
