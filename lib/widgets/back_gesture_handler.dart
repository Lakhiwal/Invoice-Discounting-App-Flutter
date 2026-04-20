import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';

/// Root-level back-gesture handler for the tabbed main screen.
///
/// This widget always intercepts back gestures (`canPop: false`) and
/// delegates to [onBackPressed] which must:
///   1. Try popping the current tab's nested navigator
///   2. Navigate back through tab history
///   3. Return false to trigger exit-toast logic
class RootBackHandler extends ConsumerStatefulWidget {
  const RootBackHandler({
    required this.child,
    required this.onBackPressed,
    super.key,
  });

  final Widget child;

  /// Called on every back gesture.
  /// Return `true` if the back was handled (nested pop or tab switch).
  /// Return `false` to trigger the exit confirmation toast.
  final Future<bool> Function() onBackPressed;

  @override
  ConsumerState<RootBackHandler> createState() => _RootBackHandlerState();
}

class _RootBackHandlerState extends ConsumerState<RootBackHandler> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final snackbarBottomMargin = 76.0 + bottomPadding + 8;

    return PopScope(
      // Always intercept — we handle ALL back navigation manually.
      // Predictive back animation works for screens pushed on the ROOT
      // navigator (profile, settings, etc.) because those routes are
      // ABOVE this PopScope in the navigation stack.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Delegate to the callback (nested pop → tab history → home)
        final handled = await widget.onBackPressed();

        if (!mounted) return;
        if (handled) return;

        // Double-tap to exit logic
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          unawaited(AppHaptics.buttonPress());

          if (!mounted) return;

          final messenger = ScaffoldMessenger.maybeOf(this.context);
          messenger?.hideCurrentSnackBar();
          messenger?.showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.back,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Press back again to exit',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF161B22),
              duration: const Duration(seconds: 2),
              elevation: 0,
              width: 220,
              dismissDirection: DismissDirection.none,
              margin: EdgeInsets.only(bottom: snackbarBottomMargin),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
          );
          return;
        }

        unawaited(SystemNavigator.pop());
      },
      child: widget.child,
    );
  }
}
