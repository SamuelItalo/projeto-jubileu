import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const _tokenKey = 'jubileu_session_token';
  static const _usernameKey = 'jubileu_session_username';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<String?> readUsername() => _storage.read(key: _usernameKey);

  Future<void> save({required String token, required String username}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _usernameKey);
  }
}
