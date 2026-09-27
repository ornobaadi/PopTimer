import 'package:flutter/material.dart';

/// Top-right settings button: a 40 dp ring with Pop Calc's tune icon,
/// inside a 48 dp touch target.
class SettingsRing extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;

  const SettingsRing({super.key, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Settings',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Icon(Icons.tune_rounded, size: 18, color: color.withValues(alpha: 0.85)),
            ),
          ),
        ),
      ),
    );
  }
}
