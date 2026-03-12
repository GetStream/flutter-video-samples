import Flutter
import UIKit
import stream_video_push_notification

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register for VoIP push notifications (PushKit).
    StreamVideoPKDelegateManager.shared.registerForPushNotifications()

    // Set self as delegate so standard (non-VoIP) push notifications
    // such as call.missed are displayed when the app is in the foreground.
    // UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Called when a notification arrives while the app is in the foreground.
  // Without this, iOS silently drops notifications when the app is active.
  // override func userNotificationCenter(
  //   _ center: UNUserNotificationCenter,
  //   willPresent notification: UNNotification,
  //   withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  // ) {
  //   let streamDict = notification.request.content.userInfo["stream"] as? [String: Any]
  //   if streamDict?["sender"] as? String != "stream.video"
  //     || streamDict?["type"] as? String != "call.missed"
  //   {
  //     return completionHandler([])
  //   }

  //   if #available(iOS 14.0, *) {
  //     completionHandler([.list, .banner, .sound])
  //   } else {
  //     completionHandler([.alert])
  //   }
  // }
}
