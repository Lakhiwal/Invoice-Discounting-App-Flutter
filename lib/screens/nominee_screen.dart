import 'package:flutter/material.dart';

import '../models/nominee.dart';
import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
import '../utils/smooth_page_route.dart';
import '../widgets/liquidity_refresh_indicator.dart';
import '../widgets/skeleton.dart';
import 'add_nominee_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void _editNominee() async {
    await AppHaptics.selection();
    if (!mounted) return;
    final updated = await Navigator.push(
      context,
      SmoothPageRoute(builder: (_) => AddNomineeScreen(nominee: _nominee)),
    );
    if (updated == true) _load(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Nominee',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: cs.surface,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
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
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.edit_outlined, color: cs.primary, size: 18),
                ),
              ),
            ),
        ],
      ),
      body: LiquidityRefreshIndicator(
        onRefresh: () => _load(forceRefresh: true, silent: true),
        color: cs.primary,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _isLoading
              ? const SingleChildScrollView(
                  key: ValueKey('loading'),
                  physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.all(24),
                  child: SkeletonNomineeList(),
                )
              : _error != null
                  ? SingleChildScrollView(
                      key: const ValueKey('error'),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: 48, color: cs.error.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(_error!,
                                style: TextStyle(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 24),
                            ElevatedButton(
                                onPressed: () => _load(forceRefresh: true), child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  : _nominee == null
                      ? SingleChildScrollView(
                          key: const ValueKey('empty'),
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.7,
                            alignment: Alignment.center,
                            child: _EmptyState(onAdd: _editNominee),
                          ),
                        )
                      : _NomineeContent(
                          key: const ValueKey('content'),
                          nominee: _nominee!,
                        ),
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  final VoidCallback onAdd;
  const _EmptyState({super.key, required this.onAdd});

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
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_alt_outlined,
                  size: 40, color: cs.primary.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 24),
            Text('No Nominee Added',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
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
              height: 48,
              child: ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Add Nominee',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NomineeContent extends ConsumerWidget {
  final Nominee nominee;
  const _NomineeContent({super.key, required this.nominee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Hero Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.1),
                  cs.primary.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.primary.withValues(alpha: 0.2), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    nominee.name.isNotEmpty ? nominee.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: cs.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(nominee.name,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(nominee.relationship,
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 14)),
                if (nominee.isMinor) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.amber(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.amber(context).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined,
                            color: AppColors.amber(context), size: 14),
                        const SizedBox(width: 6),
                        Text('Minor Nominee',
                            style: TextStyle(
                                color: AppColors.amber(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Details Card
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                _DetailTile(label: 'Full Name', value: nominee.name),
                _DetailTile(label: 'Relationship', value: nominee.relationship),
                _DetailTile(label: 'Age', value: '${nominee.age} years'),
                _DetailTile(label: 'Gender', value: nominee.gender),
                if (nominee.isMinor && nominee.guardianName.isNotEmpty)
                  _DetailTile(label: 'Guardian', value: nominee.guardianName),
                _DetailTile(label: 'Address', value: nominee.address, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends ConsumerWidget {
  final String label, value;
  final bool isLast;

  const _DetailTile({required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 24),
              Expanded(
                child: Text(value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: cs.outlineVariant.withValues(alpha: 0.15),
          ),
      ],
    );
  }
}