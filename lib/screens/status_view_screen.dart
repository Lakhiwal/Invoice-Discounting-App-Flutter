import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/models/status_story.dart';
import 'package:invoice_discounting_app/services/status_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';

class StatusViewScreen extends ConsumerStatefulWidget {
  const StatusViewScreen({required this.status, super.key});
  final StatusStory status;

  @override
  ConsumerState<StatusViewScreen> createState() => _StatusViewScreenState();
}

class _StatusViewScreenState extends ConsumerState<StatusViewScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextSlide();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextSlide() {
    if (_currentIndex < widget.status.imageUrls.length - 1) {
      if (mounted) {
        setState(() {
          _currentIndex++;
        });
        _animController.reset();
        AppHaptics.selection();
      }
    } else {
      _close();
    }
  }

  void _prevSlide() {
    if (_currentIndex > 0) {
      if (mounted) {
        setState(() {
          _currentIndex--;
        });
        _animController.reset();
        AppHaptics.selection();
      }
    } else {
      // Restart current slide if it's the first one
      _animController.reset();
    }
  }

  void _close() {
    // markAsSeen is handled by PopScope now
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            ref.read(statusProvider.notifier).markAsSeen();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onLongPressStart: (_) => _animController.stop(),
            onLongPressEnd: (_) => _animController.forward(),
            child: Stack(
              children: [
                // ── Image Background ──────────────────────────────────────────
                Positioned.fill(
                  child: CachedNetworkImage(
                    key: ValueKey(widget.status.imageUrls[_currentIndex]),
                    imageUrl: widget.status.imageUrls[_currentIndex],
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white24),
                    ),
                    imageBuilder: (context, imageProvider) {
                      // Only start animation if not already running and at start
                      if (!_animController.isAnimating &&
                          _animController.value == 0) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _animController.forward();
                        });
                      }
                      return Image(image: imageProvider, fit: BoxFit.contain);
                    },
                    errorWidget: (context, url, error) => Center(
                      child: Icon(AppIcons.error, color: Colors.white24),
                    ),
                  ),
                ),

                // ── Tap Areas ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _prevSlide,
                        behavior: HitTestBehavior.translucent,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _nextSlide,
                        behavior: HitTestBehavior.translucent,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),

                // ── Progress Indicators ─────────────────────────────────────
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, _) => Row(
                        children: List.generate(
                          widget.status.imageUrls.length,
                          (index) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(UI.radiusSm),
                                child: LinearProgressIndicator(
                                  value: index == _currentIndex
                                      ? _animController.value
                                      : (index < _currentIndex ? 1.0 : 0.0),
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                  minHeight: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
