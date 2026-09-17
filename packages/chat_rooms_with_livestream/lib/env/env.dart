/// Demo credentials for this sample.
///
/// Replace the values below with your own Stream API key and user tokens if you
/// want to point the sample at your own Stream app. For development you can
/// generate user tokens with Stream's online tool:
/// https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens
/// For production apps, generate tokens on your server rather than in the client.
///
/// IMPORTANT: The predefined API key, sample users, tokens, and the room ids in
/// this sample should be treated as publicly accessible demo values. If you
/// reuse them, other people running the sample may join the same rooms and
/// livestreams.
///
/// Every value below can be overridden at build time without editing this file,
/// which is how the benchmark points the sample at a private Stream app:
///
/// ```bash
/// flutter run --dart-define-from-file=bench_env.json
/// ```
///
/// The defaults are the public demo values, so running the sample with no
/// defines behaves exactly as documented in the README. The user *ids* are not
/// overridable - only the key and the tokens - so a private app just needs
/// tokens minted for these same six ids.
abstract class Env {
  /// Shared by Stream Chat and Stream Video - one project, one key.
  static const String streamApiKey = String.fromEnvironment(
    'STREAM_API_KEY',
    defaultValue: 'mmhfdzb5evj2',
  );

  static const String sampleUserId00 = 'alice_johnson';
  static const String sampleUserName00 = 'Alice Johnson';
  static const String sampleUserImage00 = 'https://robohash.org/alice_johnson';
  static const String sampleUserToken00 = String.fromEnvironment(
    'STREAM_TOKEN_00',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYWxpY2Vfam9obnNvbiJ9.v6-yXWgbLyykj9yt_ophmaC5FCGAG9ic6p02V09CmKQ',
  );

  static const String sampleUserId01 = 'bob_smith';
  static const String sampleUserName01 = 'Bob Smith';
  static const String sampleUserImage01 = 'https://robohash.org/bob_smith';
  static const String sampleUserToken01 = String.fromEnvironment(
    'STREAM_TOKEN_01',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYm9iX3NtaXRoIn0.rYCa73497wMkuiNC9P8xoEiiXlMxX_CJwBzU33-ZbHY',
  );

  static const String sampleUserId02 = 'carol_davis';
  static const String sampleUserName02 = 'Carol Davis';
  static const String sampleUserImage02 = 'https://robohash.org/carol_davis';
  static const String sampleUserToken02 = String.fromEnvironment(
    'STREAM_TOKEN_02',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiY2Fyb2xfZGF2aXMifQ.2_qXNlnlSeAJz_YVB6goKSne2KD2b_zMT5SwXHY0MLo',
  );

  static const String sampleUserId03 = 'david_lee';
  static const String sampleUserName03 = 'David Lee';
  static const String sampleUserImage03 = 'https://robohash.org/david_lee';
  static const String sampleUserToken03 = String.fromEnvironment(
    'STREAM_TOKEN_03',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZGF2aWRfbGVlIn0.7cMS9jgKUZyX1nrZxIlFQSCaesf2Wijx6jsNvPYdabs',
  );

  static const String sampleUserId04 = 'eva_martinez';
  static const String sampleUserName04 = 'Eva Martinez';
  static const String sampleUserImage04 = 'https://robohash.org/eva_martinez';
  static const String sampleUserToken04 = String.fromEnvironment(
    'STREAM_TOKEN_04',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZXZhX21hcnRpbmV6In0.132_gPKxhGNDZMUAPMaT6FWG1-3ZcRlVb3Ck4v42dXI',
  );

  static const String sampleUserId05 = 'frank_wilson';
  static const String sampleUserName05 = 'Frank Wilson';
  static const String sampleUserImage05 = 'https://robohash.org/frank_wilson';
  static const String sampleUserToken05 = String.fromEnvironment(
    'STREAM_TOKEN_05',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZnJhbmtfd2lsc29uIn0._QhcO-4JhbK2O-Mh91iPX2fgpoExEbS0cSBhO5IYC1A',
  );
}
