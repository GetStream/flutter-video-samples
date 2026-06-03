import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight credential model that survives app termination via
/// [SharedPreferences].  Modelled after the dogfooding app's
/// `UserCredentials` + `AppPreferences` but collapsed into a single file
/// for simplicity.
class UserCredentials {
  const UserCredentials({
    required this.userId,
    required this.userName,
    required this.userToken,
  });

  /// Parses [json] into [UserCredentials], or returns `null` when any required
  /// field is missing or not a [String] (e.g. legacy or corrupted data).
  static UserCredentials? tryParse(Map<String, Object?> json) {
    final userId = json['userId'];
    final userName = json['userName'];
    final userToken = json['userToken'];
    if (userId is! String || userName is! String || userToken is! String) {
      return null;
    }
    return UserCredentials(
      userId: userId,
      userName: userName,
      userToken: userToken,
    );
  }

  final String userId;
  final String userName;
  final String userToken;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'userName': userName,
    'userToken': userToken,
  };
}

/// Persists [UserCredentials] in [SharedPreferences] so the background
/// isolate (FCM handler) and a cold-started app can restore them.
class CredentialStore {
  CredentialStore._(this._prefs);

  static const String _key = 'user_credentials';

  final SharedPreferences _prefs;

  static Future<CredentialStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CredentialStore._(prefs);
  }

  UserCredentials? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return UserCredentials.tryParse(decoded);
    } catch (_) {
      // Corrupted/legacy blob — treat as no stored credentials.
      return null;
    }
  }

  Future<void> save(UserCredentials credentials) {
    return _prefs.setString(_key, jsonEncode(credentials.toJson()));
  }

  Future<void> clear() => _prefs.remove(_key);
}
