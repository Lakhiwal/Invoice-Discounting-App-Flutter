import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RootBackHandler extends ConsumerStatefulWidget {
  final Widget child;
  /// Called before the exit toast. If this returns true, the exit toast is skipped.
  final Future<bool> Function()? onPopRequested;
  final bool isHomeTab;
  final bool? canPop;

  const RootBackHandler({
    super.key,
    required this.child,
    this.onPopRequested,
    this.isHomeTab = false,
    this.canPop,
  });

  @override
  ConsumerState<RootBackHandler> createState() => _RootBackHandlerState();
}

class _RootBackHandlerState extends ConsumerState<RootBackHandler> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canPop ?? false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1) First attempt the custom handler (handles nested pops or tab changes)
        final handled = await widget.onPopRequested?.call() ?? false;
        
        // If it was already handled (e.g. popped a sub-screen), we don't show the toast.
        if (handled) return;

        // 2) Standard double-tap to exit logic for the root screen.
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
                content: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'Press back again to exit',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1A1D21),
                duration: const Duration(seconds: 2),
                elevation: 4,
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          return;
        }

        SystemNavigator.pop();
      },
      child: widget.child,
    );
  }
}
