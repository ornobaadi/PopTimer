import 'package:shared_preferences/shared_preferences.dart';

/// User settings. Loaded before `runApp`.
class Settings {
  final String skinId;
  final bool hapticsEnabled;
  final bool liteEffects;

  /// Numeral parallax from the device's motion sensor.
  final bool deviceTilt;

  const Settings({
    this.skinId = 'graphite',
    this.hapticsEnabled = true,
    this.liteEffects = false,
    this.deviceTilt = true,
  });

  Settings copyWith({String? skinId, bool? hapticsEnabled, bool? liteEffects, bool? deviceTilt}) =>
      Settings(
        skinId: skinId ?? this.skinId,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        liteEffects: liteEffects ?? this.liteEffects,
        deviceTilt: deviceTilt ?? this.deviceTilt,
      );
}

abstract interface class SettingsStore {
  Settings load();
  Future<void> save(Settings settings);
}

class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Settings load() => Settings(
    skinId: _prefs.getString('settings_skin') ?? 'graphite',
    hapticsEnabled: _prefs.getBool('settings_haptics') ?? true,
    liteEffects: _prefs.getBool('settings_lite') ?? false,
    deviceTilt: _prefs.getBool('settings_tilt') ?? true,
  );

  @override
  Future<void> save(Settings s) async {
    await _prefs.setString('settings_skin', s.skinId);
    await _prefs.setBool('settings_haptics', s.hapticsEnabled);
    await _prefs.setBool('settings_lite', s.liteEffects);
    await _prefs.setBool('settings_tilt', s.deviceTilt);
  }
}

class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([this._settings = const Settings()]);

  Settings _settings;

  @override
  Settings load() => _settings;

  @override
  Future<void> save(Settings settings) async => _settings = settings;
}
