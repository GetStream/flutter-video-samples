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

  factory UserCredentials.fromJson(Map<String, Object?> json) {
    return UserCredentials(
      userId: json['userId']! as String,
      userName: json['userName']! as String,
      userToken: json['userToken']! as String,
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
    return UserCredentials.fromJson(
      jsonDecode(raw) as Map<String, Object?>,
    );
  }

  Future<void> save(UserCredentials credentials) {
    return _prefs.setString(_key, jsonEncode(credentials.toJson()));
  }

  Future<void> clear() => _prefs.remove(_key);
}
