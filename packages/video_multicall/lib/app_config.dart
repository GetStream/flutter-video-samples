/// Configure the values below so the app works with your Stream app.
///
/// CONFIGURATION REQUIRED TO USE YOUR OWN STREAM CREDENTIALS
///
/// To use this project with your Stream App credentials:
///
/// 1. Replace the `streamApiKey` below with your Stream API key from the
///    Stream Dashboard (https://dashboard.getstream.io/).
///
/// 2. Generate new user tokens for your test users using the Stream
///    token generator:
///    https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens
///
/// 3. Update the user IDs and tokens below to match your users.
///
/// IMPORTANT: The predefined API key, user credentials, and room IDs in this
/// sample should be treated as publicly accessible demo values. If you reuse
/// them, other people running the sample may join the same rooms and calls.
class AppConfig {
  AppConfig._();

  /// Your Stream API key from the Stream Dashboard
  static const String streamApiKey = 'mmhfdzb5evj2';

  // Two predefined users for testing on two devices
  static const String user1Id = 'alice_johnson';
  static const String user1Name = 'Alice Johnson';
  static const String user1Token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYWxpY2Vfam9obnNvbiJ9.v6-yXWgbLyykj9yt_ophmaC5FCGAG9ic6p02V09CmKQ';

  static const String user2Id = 'bob_smith';
  static const String user2Name = 'Bob Smith';
  static const String user2Token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYm9iX3NtaXRoIn0.rYCa73497wMkuiNC9P8xoEiiXlMxX_CJwBzU33-ZbHY';

  // Predefined call room IDs
  static const String roomAlphaId = 'multicall-room-alpha';
  static const String roomAlphaName = 'Room Alpha';

  static const String roomBravoId = 'multicall-room-bravo';
  static const String roomBravoName = 'Room Bravo';
}
