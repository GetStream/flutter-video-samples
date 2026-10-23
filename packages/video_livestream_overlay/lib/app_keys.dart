import 'env_setup.dart';

/// Stream credentials used by the sample app.
///
/// The API key and the user tokens are not part of the source code. They are
/// read from `env/env.json` when the app starts, see [load].
///
/// Create `env/env.json` by running `scripts/generate_env.sh` from the
/// repository root, or copy `env/env.example.json` and fill it in by hand. See
/// the README for details.
class AppKeys {
  static Map<String, String> _env = const {};

  /// Reads the values from `env/env.json`. Call before using the config.
  static Future<void> load() async => _env = await loadEnv();

  /// Your Stream API key from the Stream Dashboard
  static String get streamApiKey => _env['STREAM_API_KEY'] ?? '';

  // User 1 credentials
  static const String user1Id = 'alice_johnson_livestream';
  static const String user1Name = 'Alice Johnson';
  static String get user1Token =>
      _env['STREAM_TOKEN_ALICE_JOHNSON_LIVESTREAM'] ?? '';

  // User 2 credentials
  static const String user2Id = 'bob_smith_livestream';
  static const String user2Name = 'Bob Smith';
  static String get user2Token =>
      _env['STREAM_TOKEN_BOB_SMITH_LIVESTREAM'] ?? '';

  // User 3 credentials
  static const String user3Id = 'charlie_brown_livestream';
  static const String user3Name = 'Charlie Brown';
  static String get user3Token =>
      _env['STREAM_TOKEN_CHARLIE_BROWN_LIVESTREAM'] ?? '';

  /// The names of the `env/env.json` entries that are missing or empty.
  static List<String> get missingEnvKeys => [
    for (final key in const [
      'STREAM_API_KEY',
      'STREAM_TOKEN_ALICE_JOHNSON_LIVESTREAM',
      'STREAM_TOKEN_BOB_SMITH_LIVESTREAM',
      'STREAM_TOKEN_CHARLIE_BROWN_LIVESTREAM',
    ])
      if ((_env[key] ?? '').isEmpty) key,
  ];
}
