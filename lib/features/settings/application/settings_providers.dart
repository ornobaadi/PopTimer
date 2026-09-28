import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';

/// `main()` overrides this with the prefs-backed store.
final settingsStoreProvider = Provider<SettingsStore>((ref) => InMemorySettingsStore());

final settingsProvider = NotifierProvider<SettingsController, Settings>(SettingsController.new);

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.read(settingsStoreProvider).load();

  Future<void> _set(Settings s) {
    state = s;
    return ref.read(settingsStoreProvider).save(s);
  }

  Future<void> setSkin(String id) => _set(state.copyWith(skinId: id));
  Future<void> setHaptics(bool on) => _set(state.copyWith(hapticsEnabled: on));
  Future<void> setLiteEffects(bool on) => _set(state.copyWith(liteEffects: on));
  Future<void> setDeviceTilt(bool on) => _set(state.copyWith(deviceTilt: on));
}

/// Lite effects: fewer extrusion layers, no blur or grain, 12 speed lines.
final liteEffectsProvider = Provider<bool>((ref) => ref.watch(settingsProvider).liteEffects);
