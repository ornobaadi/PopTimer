import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/session.dart';

/// Persists the active session and the last-used preset. Reads are
/// synchronous so the session is restored before the first frame.
abstract interface class SessionStore {
  Session? loadSession();
  Future<void> saveSession(Session session);
  Future<void> clearSession();

  int? get lastPresetMinutes;
  Future<void> saveLastPreset(int minutes);

  /// Re-reads from disk, picking up changes made while the app was in the
  /// background (the notification action handler writes here in Phase 4).
  Future<void> reload();
}

class PrefsSessionStore implements SessionStore {
  PrefsSessionStore(this._prefs);

  final SharedPreferences _prefs;

  static const _sessionKey = 'active_session';
  static const _lastPresetKey = 'last_preset_minutes';

  @override
  Session? loadSession() {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null) return null;
    try {
      return Session.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } on Object {
      // A corrupt blob must never brick launch; drop it.
      _prefs.remove(_sessionKey);
      return null;
    }
  }

  @override
  Future<void> saveSession(Session session) =>
      _prefs.setString(_sessionKey, jsonEncode(session.toJson()));

  @override
  Future<void> clearSession() => _prefs.remove(_sessionKey);

  @override
  int? get lastPresetMinutes => _prefs.getInt(_lastPresetKey);

  @override
  Future<void> saveLastPreset(int minutes) => _prefs.setInt(_lastPresetKey, minutes);

  @override
  Future<void> reload() => _prefs.reload();
}

/// For tests.
class InMemorySessionStore implements SessionStore {
  InMemorySessionStore({Session? session, this.lastPresetMinutes})
    : _json = session == null ? null : jsonEncode(session.toJson());

  String? _json;

  @override
  int? lastPresetMinutes;

  @override
  Session? loadSession() => _json == null
      ? null
      : Session.fromJson((jsonDecode(_json!) as Map).cast<String, Object?>());

  @override
  Future<void> saveSession(Session session) async => _json = jsonEncode(session.toJson());

  @override
  Future<void> clearSession() async => _json = null;

  @override
  Future<void> saveLastPreset(int minutes) async => lastPresetMinutes = minutes;

  @override
  Future<void> reload() async {}
}
