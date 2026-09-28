import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poptimer/core/engine/presets.dart';
import 'package:poptimer/core/render/glyph_renderer.dart';
import 'package:poptimer/core/theme/skins.dart';
import 'package:poptimer/features/timer/presentation/widgets/preset_pager.dart';
import 'package:poptimer/features/timer/presentation/widgets/sculpted_numeral.dart';

import 'widget/app_harness.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  SculptedNumeral centred(WidgetTester tester) {
    final centre = tester.getCenter(find.byType(PageView));
    return tester
        .widgetList<SculptedNumeral>(find.byType(SculptedNumeral))
        .firstWhere((n) => tester.getRect(find.byWidget(n)).contains(centre));
  }

  testWidgets('opens on the 5 minute preset with its neighbours peeking', (tester) async {
    final app = AppHarness(tester);
    await app.pumpApp();

    expect(find.bySemanticsLabel('Settings'), findsOneWidget);
    expect(find.bySemanticsLabel('5 minute timer'), findsOneWidget);
    expect(centred(tester).text, '5');
    // 10 above and 3 below are built and partly on screen.
    expect(find.text('TAP TO START'), findsNothing);
    final texts = tester.widgetList<SculptedNumeral>(find.byType(SculptedNumeral)).map((n) => n.text);
    expect(texts, containsAll(['3', '5', '10']));
  });

  testWidgets('swiping up brings in the smaller preset below and remembers it', (tester) async {
    final app = AppHarness(tester);
    await app.pumpApp();

    await tester.fling(find.byType(PageView), const Offset(0, -300), 1500);
    await tester.pumpAndSettle();
    expect(centred(tester).text, '3');
    expect(app.store.lastPresetMinutes, 3);
    expect(app.haptics.events, ['pageSnap']);
  });

  testWidgets('+ sits below 1 at the bottom', (tester) async {
    phone(tester);
    int? page;
    await tester.pumpWidget(
      MaterialApp(
        home: PresetPager(
          presets: defaultPresets,
          initialIndex: 0,
          material: _material,
          onPageChanged: (i) => page = i,
        ),
      ),
    );
    await tester.fling(find.byType(PageView), const Offset(0, -300), 1500);
    await tester.pumpAndSettle();
    expect(page, PresetPager.stopwatchIndex(defaultPresets));
    expect(find.bySemanticsLabel('Stopwatch'), findsOneWidget);
  });

  testWidgets('a disabled pager does not scroll', (tester) async {
    phone(tester);
    int? page;
    await tester.pumpWidget(
      MaterialApp(
        home: PresetPager(
          presets: defaultPresets,
          initialIndex: 3,
          material: _material,
          enabled: false,
          onPageChanged: (i) => page = i,
        ),
      ),
    );
    await tester.fling(find.byType(PageView), const Offset(0, -300), 1500);
    await tester.pumpAndSettle();
    expect(page, isNull);
  });
}

final _material = GlyphMaterial.idle(Skins.graphite.night);
