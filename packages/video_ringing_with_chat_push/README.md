# Ringing Example (Video + Chat with Push)

📚 [Ringing Tutorial](https://getstream.io/video/sdk/flutter/tutorial/ringing/) · This sample adds **Stream Chat** and push notifications (chat + incoming call / missed call) on top of the same ringing setup.

The app demonstrates video calling with ringing (incoming call notifications), plus chat channels and push notifications. Configure `env/env.json` and the project files below so the app works with your Stream app and Firebase project.

> [!IMPORTANT]
> This sample needs your own Stream API key and user tokens. See [Stream Configuration](#2-stream-configuration) before running it.

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

The sample doesn't contain any Stream credentials. It reads the API key, the user tokens, and the push provider names from `env/env.json` when it starts:

| Key | Value |
| --- | --- |
| `STREAM_API_KEY` | Your Stream API key from the [Stream Dashboard](https://dashboard.getstream.io/) |
| `STREAM_IOS_PUSH_PROVIDER` | The name of your APN provider in the Stream Dashboard (default: `apn-flutter-sample`) |
| `STREAM_ANDROID_PUSH_PROVIDER` | The name of your Firebase provider in the Stream Dashboard (default: `flutter-firebase`) |
| `STREAM_TOKEN_ALICE_JOHNSON` | A user token for `alice_johnson` |
| `STREAM_TOKEN_BOB_SMITH` | A user token for `bob_smith` |
| `STREAM_TOKEN_CHARLIE_BROWN` | A user token for `charlie_brown` |

The quickest way to create it is the generator script in the repository root. It asks for your API key and secret and signs the tokens locally. The secret is not stored:

```bash
scripts/generate_env.sh packages/video_ringing_with_chat_push
```

If your push providers have different names in the Stream Dashboard, update them in `env/env.json`. Alternatively, copy `env/env.example.json` to `env/env.json` and fill in the values yourself. You can generate user tokens with the [token generator](https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens).

Then run the sample as usual with `flutter run` or from your IDE. If `env/env.json` is missing values, the app shows a setup screen listing them. `env/env.json` is ignored by git, so your credentials stay out of the repository.

> [!NOTE]
> `env/env.json` is bundled with the app, and tokens created this way don't expire. That's fine for trying the sample out, but in a production app, generate tokens on your server.

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
- **Solutions**: Check token expiration (e.g. with [jwt.io](https://jwt.io)). Make sure the tokens were generated with your app’s secret.

### Ringing / push issues

- **Symptoms**: Call notifications not working, ringing not functioning.
- **Solutions**:
  - Use unique call IDs for each new call (e.g. UUID).
  - Do not call yourself (same user on two devices).
  - Ensure call recipients have connected to Stream at least once.
  - Ensure members exist on Stream’s platform.
  - Ensure push provider names in `env/env.json` match the Stream Dashboard.
  - Verify certificates and keys are valid.

### iOS CallKit

- **Symptoms**: Call notifications not showing, CallKit not working.
- **Solutions**:
  - Disable Do Not Disturb and Focus modes when testing.
  - Check that the VoIP certificate matches your bundle ID.
  - Ensure bundle ID matches the Stream Dashboard configuration.
  - Confirm push provider names in `env/env.json` match the Dashboard.
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
