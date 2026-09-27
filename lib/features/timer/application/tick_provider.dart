import 'package:flutter/scheduler.dart';

import '../../../core/engine/clock.dart';

/// Frame-synced "now" for a visible session. The UI owns it: it runs only
/// while started (a session is on screen, not paused) and Flutter stops
/// producing frames on its own while the app is in the background.
///
/// It never counts ticks. Each frame just reads [clock] and hands the time
/// to [onTick]; everything shown is derived from that.
class FrameClock {
  FrameClock({
    required TickerProvider vsync,
    required this.clock,
    required this.onTick,
  }) {
    _ticker = vsync.createTicker((_) => onTick(clock.now()));
  }

  final Clock clock;
  final void Function(DateTime now) onTick;
  late final Ticker _ticker;

  bool get isRunning => _ticker.isActive;

  void start() {
    if (!_ticker.isActive) _ticker.start();
  }

  void stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  void dispose() => _ticker.dispose();
}
