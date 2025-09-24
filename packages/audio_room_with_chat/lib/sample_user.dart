/// Class that defines a user for this sample app.
class SampleUser {
  /// Creates a new sample user.
  const SampleUser({
    required this.id,
    required this.name,
    required this.role,
    required this.image,
    required this.token,
  });

  /// User id.
  final String id;

  /// User name.
  final String name;

  /// User role.
  final String role;

  /// User avatar.
  final String image;

  /// Stream API token.
  final String token;
}
