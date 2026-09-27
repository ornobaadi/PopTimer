/// Default pager list, top to bottom. The `+` stopwatch page is implicit
/// after the last entry.
const List<int> defaultPresets = [1, 2, 3, 5, 10, 15, 20, 25, 30, 45, 60, 90];

/// Preset the app opens on at first launch.
const int defaultPresetMinutes = 5;

const int minCustomMinutes = 1;
const int maxCustomMinutes = 180;
const int maxRecents = 3;

/// Returns [presets] with [minutes] inserted in sorted order (no duplicates).
List<int> insertPreset(List<int> presets, int minutes) {
  if (presets.contains(minutes)) return List.unmodifiable(presets);
  return List.unmodifiable([...presets, minutes]..sort());
}

/// Returns [recents] with [minutes] moved to the front, capped at [maxRecents].
List<int> addRecent(List<int> recents, int minutes) => List.unmodifiable(
  [minutes, ...recents.where((m) => m != minutes)].take(maxRecents),
);

/// Index of [minutes] in [presets], or the default preset if it's missing.
int presetIndexOf(List<int> presets, int minutes) {
  final i = presets.indexOf(minutes);
  if (i >= 0) return i;
  final fallback = presets.indexOf(defaultPresetMinutes);
  return fallback >= 0 ? fallback : 0;
}
