class StoredSession {
  final String token;
  final String usersOrigin;
  const StoredSession(this.token, this.usersOrigin);
}

abstract class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> delete();
}
