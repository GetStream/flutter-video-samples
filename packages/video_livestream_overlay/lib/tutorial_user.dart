import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_keys.dart';

/// One of the predefined demo users that can be logged into the sample.
class TutorialUser {
  const TutorialUser({required this.user, required this.token});

  final User user;
  final String? token;

  factory TutorialUser.user1() => TutorialUser(
        user: User.regular(
          userId: AppKeys.user1Id,
          name: AppKeys.user1Name,
          image:
              'https://images.pexels.com/photos/774909/pexels-photo-774909.jpeg?auto=compress&cs=tinysrgb&w=600',
        ),
        token: AppKeys.user1Token,
      );

  factory TutorialUser.user2() => TutorialUser(
        user: User.regular(
          userId: AppKeys.user2Id,
          name: AppKeys.user2Name,
          image:
              'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg?auto=compress&cs=tinysrgb&w=600',
        ),
        token: AppKeys.user2Token,
      );

  factory TutorialUser.user3() => TutorialUser(
        user: User.regular(
          userId: AppKeys.user3Id,
          name: AppKeys.user3Name,
          image:
              'https://images.pexels.com/photos/1681010/pexels-photo-1681010.jpeg?auto=compress&cs=tinysrgb&w=600',
        ),
        token: AppKeys.user3Token,
      );

  static List<TutorialUser> get users => [
        TutorialUser.user1(),
        TutorialUser.user2(),
        TutorialUser.user3(),
      ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TutorialUser && other.user.id == user.id;
  }

  @override
  int get hashCode => user.id.hashCode;
}
