import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lite effects (fewer extrusion layers, no blur or grain, 12 speed lines).
/// Becomes a persisted setting with the settings sheet in Phase 5.
final liteEffectsProvider = Provider<bool>((ref) => false);
