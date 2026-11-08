import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../domain/services/session_store.dart';

/// One encrypted record prevents mismatched token/origin writes.
class SecureSessionStore implements SessionStore {
  final FlutterSecureStorage _storage;
  static const _key = 'users_session_v1';
  const SecureSessionStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<StoredSession?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    final data = jsonDecode(value);
    if (data is! Map ||
        data['token'] is! String ||
        (data['token'] as String).isEmpty ||
        data['origin'] is! String) {
      throw const FormatException('Sesión almacenada inválida');
    }
    return StoredSession(data['token'], data['origin']);
  }

  @override
  Future<void> write(StoredSession session) => _storage.write(
    key: _key,
    value: jsonEncode({'token': session.token, 'origin': session.usersOrigin}),
  );

  @override
  Future<void> delete() => _storage.delete(key: _key);
}
