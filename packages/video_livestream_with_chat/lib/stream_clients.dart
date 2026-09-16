import 'package:stream_chat_flutter/stream_chat_flutter.dart' as chat;
import 'package:stream_video_flutter/stream_video_flutter.dart' as video;

import 'app_config.dart';

/// Connects and disconnects the Video and Chat clients for a [SampleUser].
///
/// Both SDKs export a `User` class, so this file is the one place that imports
/// them side by side (behind prefixes). Every other file in the sample only
/// imports the SDK it actually needs.
class StreamClients {
  StreamClients._();

  /// Connects [user] to the Video API.
  ///
  /// Resets any previous session first so switching users in the picker
  /// doesn't leave a stale connection behind.
  static Future<void> connectVideo(SampleUser user) async {
    if (video.StreamVideo.isInitialized()) {
      await video.StreamVideo.reset(disconnect: true);
    }

    final client = video.StreamVideo(
      AppConfig.streamApiKey,
      user: video.User.regular(userId: user.id, name: user.name),
      userToken: user.token,
      options: video.StreamVideoOptions(logPriority: video.Priority.debug),
    );

    await client.connect();
  }

  /// Connects [user] to the Chat API with the same token used for Video.
  static Future<void> connectChat(
    chat.StreamChatClient client,
    SampleUser user,
  ) {
    return client.connectUser(
      chat.User(id: user.id, name: user.name, image: user.image),
      user.token,
    );
  }

  /// Disconnects the current user from both products.
  static Future<void> disconnect(chat.StreamChatClient client) async {
    await client.disconnectUser();

    if (video.StreamVideo.isInitialized()) {
      await video.StreamVideo.reset(disconnect: true);
    }
  }
}
