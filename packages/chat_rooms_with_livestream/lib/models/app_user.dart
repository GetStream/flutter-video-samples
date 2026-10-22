import '../env/env.dart';

/// What a signed-in person is allowed to do.
///
/// This is an **app-level** role, not a Stream role. Both kinds of user connect
/// to Stream as the regular `user` role; the difference is purely which UI
/// affordances the app offers them. A real app would carry this on the Stream
/// user object (or on its own backend) and mirror it into Stream Video call
/// roles server-side.
enum AppRole {
  /// Can read and post in every room, and watch livestreams.
  member('Member', 'Chat in rooms, watch every stream'),

  /// Everything a member can do, plus starting a livestream inside a room.
  creator('Creator', 'Chat in rooms and go live from any room');

  const AppRole(this.label, this.blurb);

  final String label;
  final String blurb;

  bool get canGoLive => this == AppRole.creator;
}

/// A predefined user this sample can sign in as.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.image,
    required this.token,
    required this.role,
  });

  /// User id, shared by Stream Chat and Stream Video.
  final String id;

  /// Display name.
  final String name;

  /// Avatar url.
  final String image;

  /// Stream user token. One JWT authenticates both Chat and Video.
  final String token;

  /// App-level role deciding whether this user can start a livestream.
  final AppRole role;
}

/// The sign-in roster: three creators and three members.
const sampleUsers = <AppUser>[
  AppUser(
    id: Env.sampleUserId00,
    name: Env.sampleUserName00,
    image: Env.sampleUserImage00,
    token: Env.sampleUserToken00,
    role: AppRole.creator,
  ),
  AppUser(
    id: Env.sampleUserId02,
    name: Env.sampleUserName02,
    image: Env.sampleUserImage02,
    token: Env.sampleUserToken02,
    role: AppRole.creator,
  ),
  AppUser(
    id: Env.sampleUserId04,
    name: Env.sampleUserName04,
    image: Env.sampleUserImage04,
    token: Env.sampleUserToken04,
    role: AppRole.creator,
  ),
  AppUser(
    id: Env.sampleUserId01,
    name: Env.sampleUserName01,
    image: Env.sampleUserImage01,
    token: Env.sampleUserToken01,
    role: AppRole.member,
  ),
  AppUser(
    id: Env.sampleUserId03,
    name: Env.sampleUserName03,
    image: Env.sampleUserImage03,
    token: Env.sampleUserToken03,
    role: AppRole.member,
  ),
  AppUser(
    id: Env.sampleUserId05,
    name: Env.sampleUserName05,
    image: Env.sampleUserImage05,
    token: Env.sampleUserToken05,
    role: AppRole.member,
  ),
];
