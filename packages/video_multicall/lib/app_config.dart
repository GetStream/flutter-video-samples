import 'env_setup.dart';

/// Configure the values below so the app works with your Stream app.
///
/// The API key and the user tokens are not part of the source code. They are
/// read from `env/env.json` when the app starts, see [load].
///
/// Create `env/env.json` by running `scripts/generate_env.sh` from the
/// repository root, or copy `env/env.example.json` and fill it in by hand. See
/// the README for details.
class AppConfig {
  AppConfig._();

  static Map<String, String> _env = const {};

  /// Reads the values from `env/env.json`. Call before using the config.
  static Future<void> load() async => _env = await loadEnv();

  /// Your Stream API key from the Stream Dashboard
  static String get streamApiKey => _env['STREAM_API_KEY'] ?? '';

  // Two predefined users for testing on two devices
  static const String user1Id = 'alice_johnson';
  static const String user1Name = 'Alice Johnson';
  static String get user1Token => _env['STREAM_TOKEN_ALICE_JOHNSON'] ?? '';

  static const String user2Id = 'bob_smith';
  static const String user2Name = 'Bob Smith';
  static String get user2Token => _env['STREAM_TOKEN_BOB_SMITH'] ?? '';

  /// The names of the `env/env.json` entries that are missing or empty.
  static List<String> get missingEnvKeys => [
    for (final key in const [
      'STREAM_API_KEY',
      'STREAM_TOKEN_ALICE_JOHNSON',
      'STREAM_TOKEN_BOB_SMITH',
    ])
      if ((_env[key] ?? '').isEmpty) key,
  ];

  // Predefined call room IDs
  static const String roomAlphaId = 'multicall-room-alpha';
  static const String roomAlphaName = 'Room Alpha';

  static const String roomBravoId = 'multicall-room-bravo';
  static const String roomBravoName = 'Room Bravo';
}
