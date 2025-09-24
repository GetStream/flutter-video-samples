import 'package:stream_chat_flutter/stream_chat_flutter.dart' as chat;
import 'package:stream_video_flutter/stream_video_flutter.dart' as video;

import 'sample_user.dart';

/// Typedef for user from the Video SDK.
typedef VideoUser = video.User;

/// Typedef for user from the Chat SDK.
typedef ChatUser = chat.User;

/// Useful mapping functions for [SampleUser].
extension SampleUserX on SampleUser {
  /// Maps a [SampleUser] into user from the Video SDK.
  VideoUser toVideoUser() => VideoUser(
    info: video.UserInfo(id: id, name: name, image: image),
  );

  /// Maps a [SampleUser] into user from the Chat SDK.
  ChatUser toChatUser() =>
      ChatUser(id: id, role: role, name: name, image: image);
}
