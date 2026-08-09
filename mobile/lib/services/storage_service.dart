import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

/// Persists and retrieves the authenticated user session securely.
class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _userKey = 'inflow_user';

  Future<void> saveUser(UserModel user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<UserModel?> loadUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(json, json['email'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() async {
    await _storage.delete(key: _userKey);
  }
}
