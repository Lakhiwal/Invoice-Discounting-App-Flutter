import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_haptics.dart';

class RootBackHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback? onBack;
  final bool isHomeTab;

  const RootBackHandler({
    super.key,
    required this.child,
    this.onBack,
    this.isHomeTab = false,
  });

  @override
  State<RootBackHandler> createState() => _RootBackHandlerState();
}

class _RootBackHandlerState extends State<RootBackHandler> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        // If onBack is provided (e.g. for switching to home tab), use it.
        if (!widget.isHomeTab && widget.onBack != null) {
          widget.onBack!();
          return;
        }

        // Otherwise (Home tab), handle double-tap to exit logic.
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          await AppHaptics.buttonPress();

          if (!mounted) return;

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.exit_to_app_rounded,
                          color: Colors.white70, size: 18),
                      SizedBox(width: 10),
                      Text('Tap again to exit',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF26292F),
                duration: const Duration(seconds: 2),
                elevation: 0,
                margin: EdgeInsets.fromLTRB(
                    16, 0, 16, MediaQuery.of(context).padding.bottom + 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08), width: 1),
                ),
              ),
            );
          return;
        }

        await AppHaptics.error();
        SystemNavigator.pop();
      },
      child: widget.child,
    );
  }
}
