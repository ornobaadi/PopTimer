import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'skin.dart';
import 'skins.dart';

/// The active skin. Graphite only until Pro skins arrive (Phase 6).
final skinProvider = Provider<Skin>((ref) => Skins.graphite);
