import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent JWT storage backed by Android Keystore / iOS Keychain --
/// equivalent role to passvault-client's localStorage["passvault.clientToken"]
/// (src/lib/api.js), but on secure OS-backed storage instead of a web
/// storage API an XSS could read.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'passvault.clientToken';

  Future<String?> read() => _storage.read(key: _tokenKey);

  Future<void> write(String? token) {
    if (token == null) return _storage.delete(key: _tokenKey);
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
