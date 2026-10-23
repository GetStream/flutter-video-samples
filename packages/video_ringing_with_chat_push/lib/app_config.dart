import 'env_setup.dart';

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
/// 5. CONFIGURE STREAM DASHBOARD AND CREATE `env/env.json`:
///    - Create a Firebase provider in Stream Dashboard for Android push notifications
///    - Create an APN provider in Stream Dashboard for iOS push notifications
///    - Create `env/env.json` with your Stream API key and user tokens by
///      running `scripts/generate_env.sh` from the repository root, or copy
///      `env/env.example.json` and fill it in by hand
///    - Set the push provider names (`STREAM_IOS_PUSH_PROVIDER` and
///      `STREAM_ANDROID_PUSH_PROVIDER`) in `env/env.json` to match your Stream
///      Dashboard configuration
///
/// The API key, the user tokens, and the push provider names are not part of
/// the source code. They are read from `env/env.json` when the app starts, see
/// [load].
class AppConfig {
  AppConfig._();

  static Map<String, String> _env = const {};

  /// Reads the values from `env/env.json`. Call before using the config.
  static Future<void> load() async => _env = await loadEnv();

  /// Your Stream API key from the Stream Dashboard
  static String get streamApiKey => _env['STREAM_API_KEY'] ?? '';

  // Push notification provider names (configure these in Stream Dashboard)
  static String get iosPushProviderName =>
      _nonEmpty(_env['STREAM_IOS_PUSH_PROVIDER']) ?? 'apn-flutter-sample';
  static String get androidPushProviderName =>
      _nonEmpty(_env['STREAM_ANDROID_PUSH_PROVIDER']) ?? 'flutter-firebase';

  // Configure at least two test users for the demo
  static const String user1Id = 'alice_johnson';
  static const String user1Name = 'Alice Johnson';
  static String get user1Token => _env['STREAM_TOKEN_ALICE_JOHNSON'] ?? '';

  static const String user2Id = 'bob_smith';
  static const String user2Name = 'Bob Smith';
  static String get user2Token => _env['STREAM_TOKEN_BOB_SMITH'] ?? '';

  static const String user3Id = 'charlie_brown';
  static const String user3Name = 'Charlie Brown';
  static String get user3Token => _env['STREAM_TOKEN_CHARLIE_BROWN'] ?? '';

  /// The names of the `env/env.json` entries that are missing or empty.
  static List<String> get missingEnvKeys => [
    for (final key in const [
      'STREAM_API_KEY',
      'STREAM_TOKEN_ALICE_JOHNSON',
      'STREAM_TOKEN_BOB_SMITH',
      'STREAM_TOKEN_CHARLIE_BROWN',
    ])
      if ((_env[key] ?? '').isEmpty) key,
  ];

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
