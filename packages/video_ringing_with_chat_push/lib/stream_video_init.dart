import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';

import 'app_config.dart';

/// Creates and initializes the foreground [StreamVideo] singleton.
StreamVideo initStreamVideo({
  required String userId,
  required String userName,
  required String userToken,
}) {
  return StreamVideo(
    AppConfig.streamApiKey,
    user: User.regular(userId: userId, name: userName),
    userToken: userToken,
    options: StreamVideoOptions(
      keepConnectionsAliveWhenInBackground: true,
      logPriority: Priority.debug,
    ),
    pushNotificationManagerProvider: StreamVideoPushNotificationManager.create(
      iosPushProvider: const StreamVideoPushProvider.apn(
        name: AppConfig.iosPushProviderName,
      ),
      androidPushProvider: const StreamVideoPushProvider.firebase(
        name: AppConfig.androidPushProviderName,
      ),
      pushConfiguration: const StreamVideoPushConfiguration(
        ios: IOSPushConfiguration(iconName: 'IconMask'),
      ),
      registerApnDeviceToken: true,
    ),
  );
}
