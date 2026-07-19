import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/subscription/revenuecat_config.dart';
import '../../data/services/subscription_service.dart';

/// Upgrade-plan paywall for a family's wallet. Only the family admin can
/// actually purchase — members can still see plans/pricing, with an
/// explanatory banner instead of purchase buttons.
class PaywallScreen extends StatefulWidget {
  final bool isAdmin;
  final String familyName;

  const PaywallScreen({
    super.key,
    required this.isAdmin,
    required this.familyName,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isAdmin,
    required String familyName,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(isAdmin: isAdmin, familyName: familyName),
      ),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = true;
  Offerings? _offerings;
  Package? _purchasingPackage;
  bool _restoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!RevenueCatConfig.isConfigured) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final offerings = await SubscriptionService.instance.getOfferings();
    if (!mounted) return;
    setState(() {
      _offerings = offerings;
      _loading = false;
      if (offerings == null) _error = 'Could not load plans. Please try again.';
    });
  }

  Future<void> _purchase(Package package) async {
    if (!widget.isAdmin || _purchasingPackage != null) return;
    setState(() => _purchasingPackage = package);
    try {
      final info = await SubscriptionService.instance.purchasePackage(package);
      if (!mounted) return;
      if (info != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan upgraded! Enjoy the new limits.')),
        );
        Navigator.pop(context);
      }
      // info == null means the user cancelled — no message needed.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _purchasingPackage = null);
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    try {
      final info = await SubscriptionService.instance.restorePurchases();
      if (!mounted) return;
      final hasEntitlement = info?.entitlements.active.isNotEmpty == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasEntitlement
                ? 'Purchases restored!'
                : 'No previous purchases found for this account.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF4F5FF);
    final card = isDark ? const Color(0xFF1A1B2E) : Colors.white;
    final tc = isDark ? Colors.white : const Color(0xFF0F172A);
    final sub = isDark ? Colors.white54 : const Color(0xFF64748B);

    final packages = _offerings?.current?.availablePackages ??
        _offerings?.all.values.expand((o) => o.availablePackages).toList() ??
        const [];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: tc,
        title: const Text(
          'Upgrade Plan',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !RevenueCatConfig.isConfigured || packages.isEmpty
                ? _EmptyState(sub: sub, error: _error)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      Text(
                        widget.familyName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a plan',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (!widget.isAdmin) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Only the family admin can upgrade the plan. '
                                  'You can still see what\'s included below.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w600,
                                    color: tc,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      ...packages.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PlanCard(
                              package: p,
                              card: card,
                              tc: tc,
                              sub: sub,
                              purchasable: widget.isAdmin,
                              purchasing: _purchasingPackage == p,
                              onTap: () => _purchase(p),
                            ),
                          )),

                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _restoring ? null : _restore,
                          child: Text(
                            _restoring ? 'Restoring…' : 'Restore purchases',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Package package;
  final Color card, tc, sub;
  final bool purchasable;
  final bool purchasing;
  final VoidCallback onTap;

  const _PlanCard({
    required this.package,
    required this.card,
    required this.tc,
    required this.sub,
    required this.purchasable,
    required this.purchasing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  product.description,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.priceString,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: purchasable && !purchasing ? onTap : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: purchasing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Select',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color sub;
  final String? error;
  const _EmptyState({required this.sub, this.error});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🛠️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                error ?? 'Plans are being set up — check back soon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  color: sub,
                ),
              ),
            ],
          ),
        ),
      );
}
