import 'dart:async';

import 'package:flutter/material.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';

class AppSwitch extends StatelessWidget {
  const AppSwitch({
    required this.value,
    required this.onChanged,
    super.key,
    this.activeColor,
    this.inactiveColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = activeColor ?? cs.primary;
    final inactive = inactiveColor ?? cs.outlineVariant.withValues(alpha: 0.18);

    return GestureDetector(
      onTap: () {
        unawaited(AppHaptics.selection());
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutExpo,
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: value ? primary : inactive,
          border: Border.all(
            color: value
                ? primary.withValues(alpha: 0.2)
                : cs.outlineVariant.withValues(alpha: 0.18),
          ),
          boxShadow: [
            if (value)
              BoxShadow(
                color: primary.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
