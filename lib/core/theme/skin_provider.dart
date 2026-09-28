import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_providers.dart';
import 'skin.dart';
import 'skins.dart';

/// The active skin, from settings.
final skinProvider = Provider<Skin>((ref) => Skins.byId(ref.watch(settingsProvider).skinId));
