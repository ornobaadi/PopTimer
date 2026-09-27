import 'package:flutter/material.dart';

import '../../../../core/theme/typography.dart';

/// The small `10:00` / `+00:03:16` line under the numeral. Scales with the
/// system font (up to 200%), unlike the decorative numeral.
///
/// Slides up 8 dp and fades in when it first appears; blinks slowly while
/// [blinking] (1 s on, 0.5 s at 40%).
class CountdownLine extends StatefulWidget {
  final String text;
  final Color color;
  final bool blinking;
  final bool reduceMotion;

  const CountdownLine({
    super.key,
    required this.text,
    required this.color,
    this.blinking = false,
    this.reduceMotion = false,
  });

  static const blinkCycle = Duration(milliseconds: 1500);

  @override
  State<CountdownLine> createState() => _CountdownLineState();
}

class _CountdownLineState extends State<CountdownLine> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: CountdownLine.blinkCycle,
  );

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _enter.value = 1;
    } else {
      _enter.forward();
    }
    _syncBlink();
  }

  @override
  void didUpdateWidget(CountdownLine old) {
    super.didUpdateWidget(old);
    if (old.blinking != widget.blinking) _syncBlink();
  }

  void _syncBlink() {
    if (widget.blinking) {
      _blink.repeat();
    } else {
      _blink
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _blink]),
      builder: (context, child) {
        final enter = Curves.easeOutCubic.transform(_enter.value);
        final blinkOpacity = widget.blinking && _blink.value > 2 / 3 ? 0.4 : 1.0;
        return Opacity(
          opacity: enter * blinkOpacity,
          child: Transform.translate(offset: Offset(0, 8 * (1 - enter)), child: child),
        );
      },
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2,
        child: Text(
          widget.text,
          textAlign: TextAlign.center,
          style: AppType.countdown(widget.color),
        ),
      ),
    );
  }
}
