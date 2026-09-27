import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poptimer/app/app.dart';
import 'package:poptimer/core/engine/presets.dart';
import 'package:poptimer/core/render/glyph_renderer.dart';
import 'package:poptimer/core/theme/skins.dart';
import 'package:poptimer/features/timer/presentation/widgets/preset_pager.dart';
import 'package:poptimer/features/timer/presentation/widgets/sculpted_numeral.dart';

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
    phone(tester);
    await tester.pumpWidget(const ProviderScope(child: PopTimerApp()));

    expect(find.text('TAP TO START'), findsOneWidget);
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);
    expect(find.bySemanticsLabel('5 minute timer'), findsOneWidget);
    expect(centred(tester).text, '5');
    // 3 above and 10 below are built and partly on screen.
    final texts = tester.widgetList<SculptedNumeral>(find.byType(SculptedNumeral)).map((n) => n.text);
    expect(texts, containsAll(['3', '5', '10']));
  });

  testWidgets('swiping up snaps to the next preset', (tester) async {
    phone(tester);
    await tester.pumpWidget(const ProviderScope(child: PopTimerApp()));

    await tester.fling(find.byType(PageView), const Offset(0, -300), 1500);
    await tester.pumpAndSettle();
    expect(centred(tester).text, '10');
  });

  testWidgets('the last page is the + stopwatch', (tester) async {
    phone(tester);
    int? page;
    await tester.pumpWidget(
      MaterialApp(
        home: PresetPager(
          presets: defaultPresets,
          initialIndex: defaultPresets.length - 1,
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
