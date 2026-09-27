import 'package:flutter/material.dart';

import '../../../../core/render/glyph_renderer.dart';
import 'sculpted_numeral.dart';
import 'timer_layout.dart';

/// Vertical snapping pager: one page per preset (minutes), then the `+`
/// stopwatch page at the bottom. Neighbours peek from the edges.
class PresetPager extends StatefulWidget {
  final List<int> presets;
  final int initialIndex;
  final GlyphMaterial material;
  final bool lite;
  final bool enabled;
  final ValueChanged<int>? onPageChanged;

  const PresetPager({
    super.key,
    required this.presets,
    required this.initialIndex,
    required this.material,
    this.lite = false,
    this.enabled = true,
    this.onPageChanged,
  });

  /// Index of the `+` page.
  static int stopwatchIndex(List<int> presets) => presets.length;

  static String labelFor(List<int> presets, int index) =>
      index >= presets.length ? '+' : '${presets[index]}';

  @override
  State<PresetPager> createState() => _PresetPagerState();
}

class _PresetPagerState extends State<PresetPager> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
    viewportFraction: TimerLayout.pageFraction,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.presets.length + 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final numeralHeight = constraints.maxHeight * TimerLayout.numeralFraction;
        return PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          physics: widget.enabled
              ? const _PageSnapPhysics()
              : const NeverScrollableScrollPhysics(),
          onPageChanged: widget.onPageChanged,
          itemCount: pageCount,
          itemBuilder: (context, index) {
            final isStopwatch = index == PresetPager.stopwatchIndex(widget.presets);
            final text = PresetPager.labelFor(widget.presets, index);
            return Semantics(
              label: isStopwatch ? 'Stopwatch' : '$text minute timer',
              hint: isStopwatch
                  ? 'Double tap to start.'
                  : 'Double tap to start. Swipe up or down for other times.',
              child: Center(
                child: SizedBox(
                  height: numeralHeight,
                  width: constraints.maxWidth,
                  child: SculptedNumeral(
                    text: text,
                    material: widget.material,
                    lite: widget.lite,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Page snapping with the `pageSnap` spring (stiffness 300, damping 30).
class _PageSnapPhysics extends PageScrollPhysics {
  const _PageSnapPhysics({super.parent});

  @override
  _PageSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _PageSnapPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 1, stiffness: 300, damping: 30);
}
