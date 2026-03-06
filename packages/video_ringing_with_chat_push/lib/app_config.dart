/// Configure the values below so the app works with your Stream app and Firebase project.
///
/// CONFIGURATION REQUIRED TO USE YOUR OWN STREAM CREDENTIALS
///
/// To use this project with your Stream App credentials, complete the following steps.
/// For more detailed instructions, see the README.md file in this project.
///
/// 1. ADD GOOGLE SERVICES FILES:
///    - Add your `google-services.json` file to `android/app/` directory
///    - Add your `GoogleService-Info.plist` file to `ios/Runner/` directory
///
/// 2. UPDATE ANDROID APPLICATION ID:
///    - In `android/app/build.gradle.kts`, change the `applicationId` to match
///      the one referenced in your `google-services.json`
///
/// 3. UPDATE iOS BUNDLE IDENTIFIER:
///    - In `ios/Runner.xcodeproj/project.pbxproj`, change the `PRODUCT_BUNDLE_IDENTIFIER`
///      to match the one referenced in your `GoogleService-Info.plist`
///
/// 4. GENERATE FIREBASE OPTIONS:
///    - Run `flutterfire configure` to generate `firebase_options.dart` with your project settings
///    - Or copy the `firebase_options.dart` file from your existing project
///
/// 5. CONFIGURE STREAM DASHBOARD AND REPLACE APP KEYS:
///    - Create a Firebase provider in Stream Dashboard for Android push notifications
///    - Create an APN provider in Stream Dashboard for iOS push notifications
///    - Replace the `streamApiKey` below with your Stream API key from the Stream Dashboard
///    - Update the push provider names (`iosPushProviderName` and `androidPushProviderName`)
///      to match your Stream Dashboard configuration
///    - Generate new user tokens for your test users using the Stream token generator:
///      https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens
class AppConfig {
  AppConfig._();

  /// Your Stream API key from the Stream Dashboard
  static const String streamApiKey = 'mmhfdzb5evj2';

  // Push notification provider names (configure these in Stream Dashboard)
  static const String iosPushProviderName = 'apn-flutter-sample';
  static const String androidPushProviderName = 'flutter-firebase';

  // Configure at least two test users for the demo
  static const String user1Id = 'alice_johnson';
  static const String user1Name = 'Alice Johnson';
  static const String user1Token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYWxpY2Vfam9obnNvbiJ9.v6-yXWgbLyykj9yt_ophmaC5FCGAG9ic6p02V09CmKQ';

  static const String user2Id = 'bob_smith';
  static const String user2Name = 'Bob Smith';
  static const String user2Token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYm9iX3NtaXRoIn0.rYCa73497wMkuiNC9P8xoEiiXlMxX_CJwBzU33-ZbHY';

  static const String user3Id = 'charlie_brown';
  static const String user3Name = 'Charlie Brown';
  static const String user3Token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiY2hhcmxpZV9icm93biJ9.Xb9gFT9TqlTCvKgB2PgN9ugSWIGguscHIxG_dQIhVWY';
}
