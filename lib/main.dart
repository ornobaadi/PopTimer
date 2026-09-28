import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/platform/platform_providers.dart';
import 'core/storage/session_store.dart';
import 'core/storage/settings_store.dart';
import 'features/settings/application/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loaded before runApp so the session is restored before the first frame.
  final prefs = await SharedPreferences.getInstance();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Edge to edge: the surface and glyphs run under the system bars.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(PrefsSessionStore(prefs)),
        settingsStoreProvider.overrideWithValue(PrefsSettingsStore(prefs)),
      ],
      child: const PopTimerApp(),
    ),
  );
}
