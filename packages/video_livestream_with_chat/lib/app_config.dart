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
/// The same token is used for both Video and Chat — one Stream app serves
/// both products, so a user only has to be authenticated once.
///
/// IMPORTANT: The predefined API key, user credentials, and IDs in this sample
/// should be treated as publicly accessible demo values. If you reuse them,
/// other people running the sample may join the same livestream and chat.
class AppConfig {
  AppConfig._();

  /// Your Stream API key from the Stream Dashboard.
  static const String streamApiKey = 'mmhfdzb5evj2';

  /// The host goes live; everyone else watches and chats.
  static const SampleUser host = SampleUser(
    id: 'alice_johnson',
    name: 'Alice Johnson',
    image: 'https://robohash.org/alice_johnson',
    token:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYWxpY2Vfam9obnNvbiJ9.v6-yXWgbLyykj9yt_ophmaC5FCGAG9ic6p02V09CmKQ',
  );

  static const List<SampleUser> viewers = [
    SampleUser(
      id: 'bob_smith',
      name: 'Bob Smith',
      image: 'https://robohash.org/bob_smith',
      token:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYm9iX3NtaXRoIn0.rYCa73497wMkuiNC9P8xoEiiXlMxX_CJwBzU33-ZbHY',
    ),
    SampleUser(
      id: 'carol_davis',
      name: 'Carol Davis',
      image: 'https://robohash.org/carol_davis',
      token:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiY2Fyb2xfZGF2aXMifQ.2_qXNlnlSeAJz_YVB6goKSne2KD2b_zMT5SwXHY0MLo',
    ),
    SampleUser(
      id: 'david_lee',
      name: 'David Lee',
      image: 'https://robohash.org/david_lee',
      token:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZGF2aWRfbGVlIn0.7cMS9jgKUZyX1nrZxIlFQSCaesf2Wijx6jsNvPYdabs',
    ),
  ];

  /// The shared livestream. The Chat channel reuses this id, so the video call
  /// and the chat channel always stay in sync.
  static const String livestreamId = 'livestream-with-chat-demo';
  static const String livestreamName = 'Live from the studio';

  /// Chat channel type used for the livestream chat.
  ///
  /// The built-in `livestream` type is the right fit here: it is open to
  /// anyone (no invite needed) and does not track read state per member,
  /// which is what you want for a high-traffic broadcast chat.
  static const String chatChannelType = 'livestream';
}

/// A demo user that can log in to this sample.
class SampleUser {
  const SampleUser({
    required this.id,
    required this.name,
    required this.image,
    required this.token,
  });

  final String id;
  final String name;
  final String image;

  /// Stream token, valid for both the Video and the Chat SDK.
  final String token;
}
