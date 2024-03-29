import 'package:chat_with_video_starter/sample_user.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import 'channel_list_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final users = sampleUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your user'),
      ),
      body: SafeArea(
        child: ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, position) {
            var user = users[position];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(user.image),
              ),
              title: Text(user.name),
              onTap: () async => _login(context, user),
            );
          },
        ),
      ),
    );
  }

  /// Connects the current user to both Video and Chat APIs and
  /// navigates the user to the home screen.
  Future<void> _login(BuildContext context, SampleUser user) async {
    _connectChatUser(context, user);
    _connectVideoUser(user);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Material(
          child: Container(
            child: Center(
               child: Text("Let's start building!"),
            ),
          ),
        )
      ),
    );
  }

  /// Connects the current user to the Chat API.
  Future<void> _connectChatUser(BuildContext context, SampleUser user) async {
    /// TODO: Connect to the Chat API.
  }

  /// Connects the current user to the Video API.
  Future<void> _connectVideoUser(SampleUser user) async {
    /// TODO: Connect to the Video API.
  }

  /// Disconnects the currently logged in user from both Video and Chat APIs
  /// and navigates back to the previous screen.
  Future<void> _logout(BuildContext context) async {
    _disconnectChatUser(context);
    _disconnectVideoUser();

    Navigator.of(context).pop();
  }

  /// Disconnects the currently logged in user from the Chat API.
  Future<void> _disconnectChatUser(BuildContext context) async {
    /// TODO: Disconnect from the Chat API.
  }

  /// Disconnects the currently logged in user from the Video API.
  Future<void> _disconnectVideoUser() async {
    /// TODO: Disconnect from the Video API.
  }
}
