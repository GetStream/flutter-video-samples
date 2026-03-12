# Ringing Example (Video + Chat with Push)

📚 [Ringing Tutorial](https://getstream.io/video/sdk/flutter/tutorial/ringing/) · This sample adds **Stream Chat** and push notifications (chat + incoming call / missed call) on top of the same ringing setup.

The app demonstrates video calling with ringing (incoming call notifications), plus chat channels and push notifications. Configure the values in `lib/app_config.dart` and the project files below so the app works with your Stream app and Firebase project.

> [!IMPORTANT]
> The predefined API key, user credentials, and any hardcoded call IDs or channel IDs in this sample should be treated as publicly accessible demo values. If you reuse them, other people running the sample may join the same calls or conversations.

## Project Setup Guide

### Prerequisites

- A Stream account with a created App (https://dashboard.getstream.io)
- Firebase project for push notifications
- Your Stream API key and user tokens

### 1. Firebase Configuration

#### Android

1. Create a new Firebase project or use an existing one.
2. Register your Android app with your desired package name.
3. Download `google-services.json` and place it in:
   ```
   android/app/google-services.json
   ```
4. Update the `applicationId` in `android/app/build.gradle.kts` to match the package name referenced in your `google-services.json`.
5. Create a Firebase provider in the Stream Dashboard: [Creating Firebase provider](https://getstream.io/video/docs/flutter/advanced/incoming-calls/providers-configuration/#creating-firebase-provider).

#### iOS

1. Register your iOS app with your desired bundle identifier in your Apple Developer account.
2. Download `GoogleService-Info.plist` and place it in:
   ```
   ios/Runner/GoogleService-Info.plist
   ```
3. Update the `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj` to match the bundle ID referenced in your `GoogleService-Info.plist`.
4. Create an APN provider in the Stream Dashboard: [Creating APNs provider](https://getstream.io/video/docs/flutter/advanced/incoming-calls/providers-configuration/#creating-apns-provider).

### 2. Stream Configuration

Update `lib/app_config.dart` with your Stream credentials:

```dart
class AppConfig {
  AppConfig._();

  // Your Stream API key from the Stream Dashboard
  static const String streamApiKey = 'YOUR_STREAM_API_KEY';

  // Push notification provider names (configure these in Stream Dashboard)
  static const String iosPushProviderName = 'YOUR_APN_PROVIDER_NAME';
  static const String androidPushProviderName = 'YOUR_FIREBASE_PROVIDER_NAME';

  // Configure at least two test users for the demo
  static const String user1Id = 'YOUR_USER_1_ID';
  static const String user1Name = 'YOUR_USER_1_NAME';
  static const String user1Token = 'YOUR_USER_1_TOKEN';

  static const String user2Id = 'YOUR_USER_2_ID';
  static const String user2Name = 'YOUR_USER_2_NAME';
  static const String user2Token = 'YOUR_USER_2_TOKEN';

  // User 3 (optional)
  static const String user3Id = 'YOUR_USER_3_ID';
  static const String user3Name = 'YOUR_USER_3_NAME';
  static const String user3Token = 'YOUR_USER_3_TOKEN';
}
```

#### How to generate user tokens

For testing, user tokens can be generated once and stored in the app. Use the [Stream token generator](https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens): provide your Stream app secret and user ID to generate a token.

### 3. Firebase Options

Generate `lib/firebase_options.dart` by running:

```bash
flutterfire configure
```

Install the FlutterFire CLI if needed:

```bash
dart pub global activate flutterfire_cli
```

## Troubleshooting

### Connection issues

- **Symptoms**: Unable to establish WebSocket connection, call setup fails.
- **Solutions**: Verify your Stream API key is correct and that tokens are valid and generated for the correct user.

### Token issues

- **Symptoms**: Authentication failures, sudden disconnections.
- **Solutions**: Check token expiration (e.g. with [jwt.io](https://jwt.io)). Use your app’s secret to generate tokens, not demo tokens.

### Ringing / push issues

- **Symptoms**: Call notifications not working, ringing not functioning.
- **Solutions**:
  - Use unique call IDs for each new call (e.g. UUID).
  - Do not call yourself (same user on two devices).
  - Ensure call recipients have connected to Stream at least once.
  - Ensure members exist on Stream’s platform.
  - Ensure push provider names in `app_config.dart` match the Stream Dashboard.
  - Verify certificates and keys are valid.

### iOS CallKit

- **Symptoms**: Call notifications not showing, CallKit not working.
- **Solutions**:
  - Disable Do Not Disturb and Focus modes when testing.
  - Check that the VoIP certificate matches your bundle ID.
  - Ensure bundle ID matches the Stream Dashboard configuration.
  - Confirm push provider names in `app_config.dart` match the Dashboard.
  - Check “Webhook & Push Logs” in the Stream Dashboard.

### Verbose logging

To enable more detailed logs:

```dart
StreamVideo(
  apiKey: AppConfig.streamApiKey,
  user: user,
  options: const StreamVideoOptions(
    logPriority: Priority.verbose,
  ),
  // ...
);
```
