import 'package:ansiedad_ml_app/domain/services/session_store.dart';

class FakeSessionStore implements SessionStore {
  StoredSession? session;
  bool failWrite = false;
  bool failDelete = false;
  @override
  Future<StoredSession?> read() async => session;
  @override
  Future<void> write(StoredSession value) async {
    if (failWrite) throw StateError('storage unavailable');
    session = value;
  }

  @override
  Future<void> delete() async {
    if (failDelete) throw StateError('storage unavailable');
    session = null;
  }
}
