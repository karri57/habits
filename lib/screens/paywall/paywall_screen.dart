import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../providers/purchase_provider.dart';
import '../../services/purchase_products.dart';
import 'retention_offer_screen.dart';

enum _Tier { monthly, yearly }

/// "Delivery Habits PRO" paywall — styled after the reference video's pushr
/// PRO screen. Gates Plaid bank sync (see AccountsScreen); manual tracking
/// stays free.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  _Tier _tier = _Tier.yearly;
  bool _freeTrial = true;
  bool _purchasing = false;

  Future<void> _handleClose() async {
    final upgraded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RetentionOfferScreen()),
    );
    if (upgraded == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _joinNow(Map<String, ProductDetails> products) async {
    final productId = _tier == _Tier.monthly ? PurchaseProducts.monthly : PurchaseProducts.yearly;
    final product = products[productId];
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription not available yet — check back soon.')),
      );
      return;
    }
    setState(() => _purchasing = true);
    try {
      await ref.read(purchaseServiceProvider).buy(product);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(purchaseProductsProvider);
    final products = productsAsync.value ?? const {};

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'delivery habits',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: _handleClose,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'commit to your\nbudget.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: const [
                  Expanded(
                    child: _FeatureChip(
                      icon: Icons.sync,
                      label: 'automatic\nbank sync',
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _FeatureChip(
                      icon: Icons.account_balance,
                      label: 'unlimited\nlinked accounts',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Expanded(
                    child: _FeatureChip(
                      icon: Icons.history,
                      label: 'full transaction\nhistory',
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _FeatureChip(
                      icon: Icons.bolt,
                      label: 'real-time\nbalances',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _PriceCard(
                      label: 'monthly',
                      price: products[PurchaseProducts.monthly]?.price ?? '\$3.99',
                      suffix: '/mo',
                      selected: _tier == _Tier.monthly,
                      onTap: () => setState(() => _tier = _Tier.monthly),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PriceCard(
                      label: 'yearly',
                      price: products[PurchaseProducts.yearly]?.price ?? '\$1.99',
                      suffix: '/mo',
                      badge: 'save 50%',
                      selected: _tier == _Tier.yearly,
                      onTap: () => setState(() => _tier = _Tier.yearly),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('activate free trial', style: TextStyle(color: Colors.white, fontSize: 15)),
                  Switch(
                    value: _freeTrial,
                    onChanged: (v) => setState(() => _freeTrial = v),
                    activeThumbColor: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'why go pro?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 8),
              const Text(
                "Manual tracking is free, forever. Pro connects your bank or "
                "card directly (via Plaid) so every delivery order is caught "
                "automatically — no typing amounts in by hand.",
                style: TextStyle(color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _purchasing ? null : () => _joinNow(products),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _purchasing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('join now', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => ref.read(purchaseServiceProvider).restore(),
                  child: const Text('Restore purchases', style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.label,
    required this.price,
    required this.suffix,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String price;
  final String suffix;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: price,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: suffix,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -10,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text(
                badge!,
                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
