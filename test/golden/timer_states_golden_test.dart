import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poptimer/core/engine/presets.dart';
import 'package:poptimer/core/render/glyph_renderer.dart';
import 'package:poptimer/core/theme/skins.dart';
import 'package:poptimer/features/timer/presentation/browse_view.dart';
import 'package:poptimer/features/timer/presentation/session_view.dart';
import 'package:poptimer/features/timer/presentation/widgets/sculpted_numeral.dart';

import 'golden_helpers.dart';

void main() {
  setUpAll(loadAppFonts);

  const skin = Skins.graphite;
  final night = skin.night;
  final paper = skin.paper;

  Future<void> golden(WidgetTester tester, String name, Widget child) async {
    usePhoneView(tester);
    await pumpScreen(tester, child);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('browse 5', (tester) async {
    await golden(
      tester,
      'browse_5',
      BrowseView(
        night: night,
        presets: defaultPresets,
        initialIndex: presetIndexOf(defaultPresets, 5),
      ),
    );
  });

  testWidgets('browse 10', (tester) async {
    await golden(
      tester,
      'browse_10',
      BrowseView(
        night: night,
        presets: defaultPresets,
        initialIndex: presetIndexOf(defaultPresets, 10),
      ),
    );
  });

  testWidgets('browse + page', (tester) async {
    await golden(
      tester,
      'browse_plus',
      BrowseView(
        night: night,
        presets: defaultPresets,
        initialIndex: defaultPresets.length,
      ),
    );
  });

  testWidgets('timer running (lit)', (tester) async {
    await golden(
      tester,
      'running_10',
      SessionView(
        tokens: night,
        numeral: '10',
        material: GlyphMaterial.lit(night),
        line: '10:00',
        semanticsLabel: '10 minutes left',
      ),
    );
  });

  testWidgets('timer paused', (tester) async {
    await golden(
      tester,
      'paused_8',
      SessionView(
        tokens: night,
        numeral: '8',
        material: GlyphMaterial.idle(night),
        line: '7:42',
        semanticsLabel: 'Paused, 7 minutes 42 seconds left',
        showSettings: true,
      ),
    );
  });

  testWidgets('timer done', (tester) async {
    await golden(
      tester,
      'done_0',
      SessionView(
        tokens: paper,
        numeral: '0',
        material: GlyphMaterial.idle(paper),
        line: '+00:00:12',
        semanticsLabel: "Time's up",
      ),
    );
  });

  testWidgets('stopwatch under a minute', (tester) async {
    await golden(
      tester,
      'stopwatch_plus',
      SessionView(
        tokens: paper,
        numeral: '+',
        material: GlyphMaterial.idle(paper),
        line: '+00:00:16',
        semanticsLabel: 'Stopwatch, 16 seconds',
      ),
    );
  });

  testWidgets('stopwatch 3 minutes', (tester) async {
    await golden(
      tester,
      'stopwatch_3',
      SessionView(
        tokens: paper,
        numeral: '3',
        material: GlyphMaterial.idle(paper),
        line: '+00:03:16',
        semanticsLabel: 'Stopwatch, 3 minutes 16 seconds',
      ),
    );
  });

  testWidgets('glyph sheet', (tester) async {
    usePhoneView(tester);
    Widget row(String digits) => Expanded(
      child: Row(
        children: [
          for (final d in digits.split(''))
            Expanded(
              child: SculptedNumeral(text: d, material: GlyphMaterial.lit(night)),
            ),
        ],
      ),
    );
    await pumpScreen(
      tester,
      ColoredBox(
        color: night.bg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [row('0123'), row('4567'), row('89+')]),
        ),
      ),
    );
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/glyph_sheet.png'));
  });
}
