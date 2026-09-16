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
        // Registers ringing calls with the Android Telecom stack, so they
        // get audio focus and can be answered or hung up from a watch, a
        // car head unit or a Bluetooth headset. On by default from Android
        // 17, where ringing does not work without it; opt-in below that.
        android: AndroidPushConfiguration(
          telecom: TelecomPushConfiguration(
            enabled: true,
            schema: 'streamvideosample',
          ),
        ),
      ),
      registerApnDeviceToken: true,
    ),
  );
}
