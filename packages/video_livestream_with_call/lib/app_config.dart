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

  // The host streams; the viewer watches and may "call" the host.
  static const String hostId = 'alice_johnson';
  static const String hostName = 'Alice Johnson';
  static String get hostToken => _env['STREAM_TOKEN_ALICE_JOHNSON'] ?? '';

  static const String viewerId = 'bob_smith';
  static const String viewerName = 'Bob Smith';
  static String get viewerToken => _env['STREAM_TOKEN_BOB_SMITH'] ?? '';

  static const String viewer2Id = 'carol_davis';
  static const String viewer2Name = 'Carol Davis';
  static String get viewer2Token => _env['STREAM_TOKEN_CAROL_DAVIS'] ?? '';

  /// The names of the `env/env.json` entries that are missing or empty.
  static List<String> get missingEnvKeys => [
    for (final key in const [
      'STREAM_API_KEY',
      'STREAM_TOKEN_ALICE_JOHNSON',
      'STREAM_TOKEN_BOB_SMITH',
      'STREAM_TOKEN_CAROL_DAVIS',
    ])
      if ((_env[key] ?? '').isEmpty) key,
  ];

  /// The shared livestream channel. Both host and viewer use this id.
  static const String livestreamId = 'livestream-with-call-demo-2';
  static const String livestreamName = 'Demo livestream';
}
