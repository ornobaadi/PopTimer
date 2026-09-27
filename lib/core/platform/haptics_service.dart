import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptic vocabulary for every event in `design.md` section 8.
abstract interface class HapticsService {
  /// Pager snaps to a preset.
  void pageSnap();

  /// Timer or stopwatch starts.
  void start();

  /// Pause or resume.
  void pauseToggle();

  /// The big numeral changes to a new minute while running.
  void minuteTick();

  /// Each second of the last 10.
  void secondTick();

  /// A hold (cancel, reset, restart) completes.
  void holdComplete();

  /// Time's up, in the app: a strong 3-pulse pattern.
  void timeUp();
}

/// One primitive in a pattern; [delayMs] is the gap before it.
class _Hit {
  final String primitive;
  final double scale;
  final int delayMs;

  const _Hit(this.primitive, this.scale, [this.delayMs = 0]);

  Map<String, Object> toMap() => {'p': primitive, 's': scale, 'd': delayMs};
}

/// Pop Calc's haptics engine: composed primitives through the native
/// `poptimer/haptics` channel on Android (see `MainActivity.kt`), with
/// Flutter's [HapticFeedback] as the fallback.
class AppHapticsService implements HapticsService {
  AppHapticsService({this.enabled = true, this.strength = 1});

  bool enabled;

  /// 0-1 user strength multiplier.
  double strength;

  static const _channel = MethodChannel('poptimer/haptics');

  /// Set false after a failed native call so we don't retry on every event.
  bool _nativeAvailable = true;

  bool get _useNative =>
      _nativeAvailable && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _play(List<_Hit> hits, Future<void> Function() fallback) {
    if (!enabled || strength <= 0) return;
    if (!_useNative) {
      fallback();
      return;
    }
    _channel
        .invokeMethod<bool>('play', {
          'hits': [for (final h in hits) h.toMap()],
          'strength': strength,
        })
        .then((played) {
          if (played != true) fallback();
        })
        .catchError((Object _) {
          _nativeAvailable = false;
          fallback();
        });
  }

  @override
  void pageSnap() => _play(const [_Hit('tick', 0.6)], HapticFeedback.selectionClick);

  @override
  void start() => _play(
    const [_Hit('quickRise', 0.6), _Hit('click', 0.9, 30)],
    HapticFeedback.mediumImpact,
  );

  @override
  void pauseToggle() => _play(const [_Hit('click', 0.5)], HapticFeedback.lightImpact);

  @override
  void minuteTick() => _play(const [_Hit('tick', 0.7)], HapticFeedback.selectionClick);

  @override
  void secondTick() => _play(const [_Hit('click', 0.55)], HapticFeedback.lightImpact);

  @override
  void holdComplete() => _play(const [_Hit('thud', 1.0)], HapticFeedback.heavyImpact);

  @override
  void timeUp() => _play(
    const [_Hit('thud', 1.0), _Hit('thud', 1.0, 90), _Hit('thud', 1.0, 90)],
    HapticFeedback.vibrate,
  );
}
