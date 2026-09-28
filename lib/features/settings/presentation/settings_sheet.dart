import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_providers.dart';
import '../../../core/theme/skin.dart';
import '../../../core/theme/skin_provider.dart';
import '../../../core/theme/skins.dart';
import '../../../core/theme/typography.dart';
import '../application/settings_providers.dart';

/// Skins and preferences, in Pop Calc's sheet layout.
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const SettingsSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final haptics = ref.read(hapticsServiceProvider);
    final t = skin.night;
    // Andy's ink is dark on gold; Graphite's is light on dark.
    final accent = t.ink;

    Switch toggle(bool value, ValueChanged<bool> onChanged) => Switch(
      value: value,
      onChanged: (v) {
        haptics.pageSnap();
        onChanged(v);
      },
      activeThumbColor: t.bg,
      activeTrackColor: accent,
      inactiveThumbColor: t.inkSoft,
      inactiveTrackColor: t.ink.withValues(alpha: 0.08),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: MediaQuery.sizeOf(context).height * 0.62,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: t.ink.withValues(alpha: 0.1), width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.inkSoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Title('SKINS', color: t.ink),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final s in Skins.all)
                          _SkinTile(
                            skin: s,
                            selected: s.id == skin.id,
                            tokens: t,
                            onTap: () {
                              haptics.pageSnap();
                              notifier.setSkin(s.id);
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: t.ink.withValues(alpha: 0.08), height: 1),
                  const SizedBox(height: 6),
                  _Row(
                    icon: Icons.vibration_rounded,
                    label: 'Haptic Feedback',
                    tokens: t,
                    trailing: toggle(settings.hapticsEnabled, notifier.setHaptics),
                  ),
                  _Row(
                    icon: Icons.screen_rotation_alt_rounded,
                    label: 'Tilt Parallax',
                    description: 'The numeral follows how you hold the phone',
                    tokens: t,
                    trailing: toggle(settings.deviceTilt, notifier.setDeviceTilt),
                  ),
                  _Row(
                    icon: Icons.speed_rounded,
                    label: 'Lite Effects Mode',
                    description: 'Lighter rendering for older phones',
                    tokens: t,
                    trailing: toggle(settings.liteEffects, notifier.setLiteEffects),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Text(
      text,
      style: TextStyle(fontFamily: AppType.labelFamily, fontSize: 32, letterSpacing: 2, color: color),
    ),
  );
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.skin,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final Skin skin;
  final bool selected;
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${skin.label} skin',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: skin.night.bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? tokens.ink : tokens.ink.withValues(alpha: 0.15),
                  width: selected ? 3 : 1.5,
                ),
              ),
              // The skin's running numeral colour, as a hint of the look.
              child: Text(
                '5',
                style: TextStyle(
                  fontFamily: AppType.labelFamily,
                  fontSize: 30,
                  height: 1,
                  color: skin.night.litFace,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              skin.label,
              style: TextStyle(
                fontFamily: AppType.labelFamily,
                fontSize: 13,
                letterSpacing: 0.5,
                color: tokens.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.tokens,
    this.description,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? description;
  final SurfaceTokens tokens;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: tokens.inkSoft, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppType.labelFamily,
                    fontSize: 20,
                    letterSpacing: 0.5,
                    color: tokens.ink,
                  ),
                ),
                if (description != null)
                  Text(
                    description!,
                    style: TextStyle(
                      fontFamily: AppType.bodyFamily,
                      fontSize: 12,
                      color: tokens.inkSoft.withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
