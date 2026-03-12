import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';
import 'login_screen.dart';

// Item #3: SECURITY TODO — raw password is passed here and injected into WebView JS.
// Replace with a one-time session token or server-side cookie auth flow.
class ProfileWebViewScreen extends StatefulWidget {
  final String email;
  final String password;
  final String name;
  final String baseUrl;

  const ProfileWebViewScreen({
    super.key,
    required this.email,
    required this.password,
    required this.name,
    required this.baseUrl,
  });

  @override
  State<ProfileWebViewScreen> createState() => _ProfileWebViewScreenState();
}

class _ProfileWebViewScreenState extends State<ProfileWebViewScreen> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _loggedIn = false;
  bool _timedOut = false;
  String _statusText = 'Signing you in…';

  // ── Timeout timer ─────────────────────────────────────────────────────────
  Timer? _loadTimer;
  static const _timeoutSeconds = 15;

  void _startLoadTimer() {
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(seconds: _timeoutSeconds), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _timedOut = true;
          _statusText = 'Connection timed out';
        });
      }
    });
  }

  void _cancelLoadTimer() => _loadTimer?.cancel();

  void _retry() {
    setState(() {
      _isLoading = true;
      _timedOut = false;
      _loggedIn = false;
      _statusText = 'Signing you in…';
    });
    _startLoadTimer();
    _controller.loadRequest(Uri.parse('${widget.baseUrl}/signin/'));
  }

  @override
  void initState() {
    super.initState();

    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() => _isLoading = true);
          _startLoadTimer();
          _handlePageStarted(url);
        },
        onPageFinished: (url) {
          _cancelLoadTimer();
          setState(() => _isLoading = false);
          _handlePageFinished(url);
        },
        onWebResourceError: (error) {
          _cancelLoadTimer();
          setState(() {
            _isLoading = false;
            _timedOut = true;
            _statusText = 'Failed to load page';
          });
        },
      ))
      ..loadRequest(Uri.parse('${widget.baseUrl}/signin/'));

    _startLoadTimer();

    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      (_controller.platform as AndroidWebViewController)
          .setOnShowFileSelector(_androidFilePicker);
    }
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  // ── Android file picker ───────────────────────────────────────────────────

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    final picker = ImagePicker();
    final acceptsImage = params.acceptTypes
        .any((t) => t.contains('image') || t.contains('*/*') || t.isEmpty);
    try {
      if (acceptsImage) {
        final source = await _showImageSourceSheet();
        if (source == null) return [];
        final file = await picker.pickImage(
            source: source, imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
        if (file == null) return [];
        return ['file://${file.path}'];
      } else {
        final file = await picker.pickMedia();
        if (file == null) return [];
        return ['file://${file.path}'];
      }
    } catch (e) {
      debugPrint('File picker error: $e');
      return [];
    }
  }

  Future<ImageSource?> _showImageSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.navyCard(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider(context),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Upload Document',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: UI.xs),
            Text('Choose how to provide the file',
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 13)),
            const SizedBox(height: 20),
            _SourceTile(
              icon: Icons.camera_alt_rounded,
              label: 'Take Photo',
              subtitle: 'Use your camera to capture document',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 10),
            _SourceTile(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              subtitle: 'Select an existing photo or file',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, null),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.divider(context)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Cancel',
                    style:
                    TextStyle(color: AppColors.textSecondary(context))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page lifecycle ────────────────────────────────────────────────────────

  void _handlePageStarted(String url) {
    if (!_loggedIn) setState(() => _statusText = 'Signing you in…');
  }

  Future<void> _handlePageFinished(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (!_loggedIn && uri.path.contains('signin')) {
      setState(() => _statusText = 'Logging in…');
      await _injectAndSubmitLogin();
      return;
    }

    if (!_loggedIn && uri.path.contains('dashboard')) {
      _loggedIn = true;
      setState(() => _statusText = 'Opening your profile…');
      await _controller.loadRequest(
        Uri.parse('${widget.baseUrl}/dashboard/?section=profile'),
      );
      return;
    }

    if (_loggedIn) setState(() => _statusText = '');
  }

  Future<void> _injectAndSubmitLogin() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final email = widget.email.replaceAll("'", "\\'");
    final password = widget.password.replaceAll("'", "\\'");

    await _controller.runJavaScript('''
      (function() {
        var emailField = document.querySelector(
          'input[name="email"], input[type="email"], #id_email'
        );
        var passwordField = document.querySelector(
          'input[name="password"], input[type="password"], #id_password'
        );
        var form = document.querySelector('form');

        if (emailField)    emailField.value    = '$email';
        if (passwordField) passwordField.value = '$password';

        if (form) {
          form.submit();
        } else {
          var btn = document.querySelector(
            'button[type="submit"], input[type="submit"]'
          );
          if (btn) btn.click();
        }
      })();
    ''');
  }

  void _onDone() {
    Navigator.of(context).pushAndRemoveUntil(
        SmoothPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F1D3A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: AppColors.textPrimary(context)),
          onPressed: _onDone,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Complete Your Profile',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            if (_statusText.isNotEmpty)
              Text(_statusText,
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 11)),
          ],
        ),
        actions: [
          if (_loggedIn)
            TextButton(
              onPressed: _onDone,
              child: Text('Done',
                  style: TextStyle(
                      color: AppColors.primary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            )
          else
            const SizedBox(width: UI.md),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: UI.md, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(
                        color: AppColors.primary(context)
                            .withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.primary(context), size: 16),
                  const SizedBox(width: UI.sm),
                  Expanded(
                    child: Text(
                      'Fill in your profile details so our team can review and approve your account.',
                      style: TextStyle(
                          color: AppColors.primary(context),
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ]),
              ),
              Expanded(child: WebViewWidget(controller: _controller)),
            ],
          ),

          // Loading overlay
          if (_isLoading && !_timedOut)
            Positioned.fill(
              child: Container(
                color: AppColors.scaffold(context).withValues(alpha: 0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: AppColors.primary(context), strokeWidth: 2.5),
                      const SizedBox(height: UI.md),
                      Text(_statusText,
                          style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Timeout / error overlay ───────────────────────────────────
          if (_timedOut)
            Positioned.fill(
              child: Container(
                color: AppColors.scaffold(context),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // Fixed: was AppColors.rose (static), now AppColors.rose(context)
                            color: AppColors.rose(context)
                                .withValues(alpha: 0.1),
                          ),
                          child: Icon(Icons.wifi_off_rounded,
                              // Fixed: was const Icon with AppColors.rose (static)
                              color: AppColors.rose(context),
                              size: 34),
                        ),
                        const SizedBox(height: 20),
                        Text('Connection timed out',
                            style: TextStyle(
                                color: AppColors.textPrimary(context),
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: UI.sm),
                        Text(
                          'The server took too long to respond. Check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 13,
                              height: 1.5),
                        ),
                        const SizedBox(height: UI.xl),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Try Again',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary(context),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _onDone,
                          child: Text('Go back',
                              style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: UI.md, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.navyLight(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary(context), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11)),
                ]),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary(context), size: 18),
        ]),
      ),
    );
  }
}