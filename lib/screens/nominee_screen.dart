import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/models/nominee.dart';
import 'package:invoice_discounting_app/screens/add_nominee_screen.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';

class NomineeScreen extends ConsumerStatefulWidget {
  const NomineeScreen({super.key});

  @override
  ConsumerState<NomineeScreen> createState() => _NomineeScreenState();
}

class _NomineeScreenState extends ConsumerState<NomineeScreen> {
  Nominee? _nominee;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false, bool silent = false}) async {
    final startTime = DateTime.now();

    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final raw = await ApiService.getNominee(forceRefresh: forceRefresh);

      // Ensure the "Syncing" state is visible for a premium feel
      if (forceRefresh) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsed < 800) {
          await Future.delayed(Duration(milliseconds: 800 - elapsed));
        }
      }

      if (!mounted) return;
      setState(() {
        _nominee = raw != null ? Nominee.fromMap(raw) : null;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load nominee details';
      });
    }
  }

  Future<void> _editNominee() async {
    unawaited(AppHaptics.selection());
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final success = await navigator.push<bool>(
      SmoothPageRoute<bool>(
        builder: (_) => AddNomineeScreen(nominee: _nominee),
      ),
    );
    if (success == true) _load(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text(
          'Nominee',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: cs.surface,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back, size: 18),
          onPressed: () {
            AppHaptics.selection();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (!_isLoading && _nominee != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _editNominee,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(AppIcons.edit, color: cs.primary, size: 16),
                ),
              ),
            ),
        ],
      ),
      body: LiquidityRefreshIndicator(
        onRefresh: () => _load(forceRefresh: true, silent: true),
        color: cs.primary,
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _isLoading
                ? SingleChildScrollView(
                    key: const ValueKey('loading'),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: const SkeletonNomineeList(),
                    ),
                  )
                : _error != null
                    ? SingleChildScrollView(
                        key: const ValueKey('error'),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Container(
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  AppIcons.error,
                                  size: 48,
                                  color: cs.error.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    unawaited(AppHaptics.selection());
                                    _load(forceRefresh: true);
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : _nominee == null
                        ? SingleChildScrollView(
                            key: const ValueKey('empty'),
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,),
                              child: Container(
                                alignment: Alignment.center,
                                child: _EmptyState(onAdd: _editNominee),
                              ),
                            ),
                          )
                        : _NomineeContent(
                            key: const ValueKey('content'),
                            nominee: _nominee!,
                          ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.05),
                borderRadius:
                    BorderRadius.circular(UI.radiusMd), // Sharp aesthetic
              ),
              child: Icon(
                AppIcons.people,
                size: 40,
                color: cs.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Nominee Added',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add a nominee to your account to ensure '
              'a smooth transfer of assets in the future.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  AppHaptics.selection();
                  onAdd();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(UI.radiusMd), // Sharp button
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add Nominee',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NomineeContent extends ConsumerWidget {
  const _NomineeContent({required this.nominee, super.key});
  final Nominee nominee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // ── Hero Section ──────────────────────────────────────────
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(UI.radiusMd),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.1),
                      width: 2,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary.withValues(alpha: 0.08),
                        cs.primary.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    nominee.name.isNotEmpty
                        ? nominee.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (nominee.isMinor)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.amber(context),
                        borderRadius: BorderRadius.circular(UI.radiusSm),
                        border: Border.all(color: cs.surface, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.amber(context).withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(AppIcons.shield, size: 12, color: cs.surface),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            nominee.name,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nominee.relationship.toUpperCase(),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 40),

          // ── Details Grid ─────────────────────────────────────────
          const _CategoryHeader(label: 'Nominee Information'),
          _SharpCard(
            children: [
              _DetailTile(
                icon: AppIcons.user,
                label: 'Legal Name',
                value: nominee.name,
                onCopy: () => _copy(context, nominee.name, 'Name'),
              ),
              _DetailTile(
                icon: AppIcons.people,
                label: 'Relationship',
                value: nominee.relationship,
              ),
              _DetailTile(
                icon: AppIcons.calendar,
                label: 'Age',
                value: '${nominee.age} Years',
              ),
              _DetailTile(
                icon: AppIcons.user,
                label: 'Gender',
                value: nominee.gender,
              ),
              if (nominee.isMinor && nominee.guardianName.isNotEmpty)
                _DetailTile(
                  icon: AppIcons.shield,
                  label: 'Guardian Name',
                  value: nominee.guardianName,
                  onCopy: () =>
                      _copy(context, nominee.guardianName, 'Guardian'),
                ),
              _DetailTile(
                icon: AppIcons.location,
                label: 'Full Address',
                value: nominee.address,
                onCopy: nominee.address.isNotEmpty
                    ? () => _copy(context, nominee.address, 'Address')
                    : null,
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String value, String label) {
    AppHaptics.selection();
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success(context),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UI.radiusSm),),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCopy != null
            ? () {
                AppHaptics.selection();
                onCopy!();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onCopy != null)
                Icon(
                  AppIcons.copy,
                  size: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharpCard extends StatelessWidget {
  const _SharpCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(UI.radiusMd),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children
            .asMap()
            .entries
            .map((e) => Column(
                  children: [
                    e.value,
                    if (e.key != children.length - 1)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 54,
                        endIndent: 16,
                        color: cs.outlineVariant.withValues(alpha: 0.1),
                      ),
                  ],
                ),)
            .toList(),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
