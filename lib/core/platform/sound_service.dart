/// Foreground alarm loop while the app is visible. The real implementation
/// (alarm audio stream, looped) lands in Phase 4.
abstract interface class SoundService {
  Future<void> startAlarm();
  Future<void> stopAlarm();
}

class NoopSoundService implements SoundService {
  const NoopSoundService();

  @override
  Future<void> startAlarm() async {}

  @override
  Future<void> stopAlarm() async {}
}
