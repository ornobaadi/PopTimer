import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../features/settings/application/settings_providers.dart';

/// Device tilt as an offset in about -1..1 on each axis (portrait, held at
/// a natural ~55°), from the accelerometer. Raw: widgets smooth it. Empty
/// when the setting is off; tests override it.
final deviceTiltProvider = Provider<Stream<Offset>>((ref) {
  if (!ref.watch(settingsProvider).deviceTilt) return const Stream.empty();
  return accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
      .map((e) => Offset((-e.x / 5.5).clamp(-1.0, 1.0), ((e.y - 6.0) / 5.5).clamp(-1.0, 1.0)))
      .handleError((Object _) {}); // no sensor: stay flat
});
