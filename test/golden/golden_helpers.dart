import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled fonts so goldens show real text, not test boxes.
Future<void> loadAppFonts() async {
  final fonts = {
    'BebasNeue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Antonio': 'assets/fonts/Antonio-VariableFont_wght.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value))).load();
  }
}

/// A 1080 x 2400 phone (360 x 800 dp at 3x) with a status bar and gesture
/// bar inset.
void usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
  addTearDown(tester.view.reset);
}

/// Pumps [child] full screen and waits for the grain texture to decode.
Future<void> pumpScreen(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: child)),
  );
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage('assets/textures/noise.png'),
      tester.element(find.byType(Scaffold)),
    );
  });
  await tester.pumpAndSettle();
}
