import '../env_setup.dart';

/// Configure the values below so the app works with your Stream app.
///
/// The API key and the user tokens are not part of the source code. They are
/// read from `env/env.json` when the app starts, see [load].
///
/// Create `env/env.json` by running `scripts/generate_env.sh` from the
/// repository root, or copy `env/env.example.json` and fill it in by hand. See
/// the README for details.
abstract class Env {
  static Map<String, String> _env = const {};

  /// Reads the values from `env/env.json`. Call before using the config.
  static Future<void> load() async => _env = await loadEnv();

  /// Your Stream API key from the Stream Dashboard
  static String get streamApiKey => _env['STREAM_API_KEY'] ?? '';

  static const String sampleUserId00 = 'alice_johnson';
  static const String sampleUserName00 = 'Alice Johnson';
  static const String sampleUserRole00 = 'user';
  static const String sampleUserImage00 = 'https://robohash.org/alice_johnson';
  static String get sampleUserToken00 =>
      _env['STREAM_TOKEN_ALICE_JOHNSON'] ?? '';

  static const String sampleUserId01 = 'bob_smith';
  static const String sampleUserName01 = 'Bob Smith';
  static const String sampleUserRole01 = 'user';
  static const String sampleUserImage01 = 'https://robohash.org/bob_smith';
  static String get sampleUserToken01 => _env['STREAM_TOKEN_BOB_SMITH'] ?? '';

  static const String sampleUserId02 = 'carol_davis';
  static const String sampleUserName02 = 'Carol Davis';
  static const String sampleUserRole02 = 'user';
  static const String sampleUserImage02 = 'https://robohash.org/carol_davis';
  static String get sampleUserToken02 => _env['STREAM_TOKEN_CAROL_DAVIS'] ?? '';

  static const String sampleUserId03 = 'david_lee';
  static const String sampleUserName03 = 'David Lee';
  static const String sampleUserRole03 = 'user';
  static const String sampleUserImage03 = 'https://robohash.org/david_lee';
  static String get sampleUserToken03 => _env['STREAM_TOKEN_DAVID_LEE'] ?? '';

  static const String sampleUserId04 = 'eva_martinez';
  static const String sampleUserName04 = 'Eva Martinez';
  static const String sampleUserRole04 = 'user';
  static const String sampleUserImage04 = 'https://robohash.org/eva_martinez';
  static String get sampleUserToken04 =>
      _env['STREAM_TOKEN_EVA_MARTINEZ'] ?? '';

  static const String sampleUserId05 = 'frank_wilson';
  static const String sampleUserName05 = 'Frank Wilson';
  static const String sampleUserRole05 = 'user';
  static const String sampleUserImage05 = 'https://robohash.org/frank_wilson';
  static String get sampleUserToken05 =>
      _env['STREAM_TOKEN_FRANK_WILSON'] ?? '';

  /// The names of the `env/env.json` entries that are missing or empty.
  static List<String> get missingEnvKeys => [
    for (final key in const [
      'STREAM_API_KEY',
      'STREAM_TOKEN_ALICE_JOHNSON',
      'STREAM_TOKEN_BOB_SMITH',
      'STREAM_TOKEN_CAROL_DAVIS',
      'STREAM_TOKEN_DAVID_LEE',
      'STREAM_TOKEN_EVA_MARTINEZ',
      'STREAM_TOKEN_FRANK_WILSON',
    ])
      if ((_env[key] ?? '').isEmpty) key,
  ];
}
