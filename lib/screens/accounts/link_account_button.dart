import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/accounts_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../theme/app_colors.dart';
import '../paywall/paywall_screen.dart';

/// "+ Add an account" button with a dashed border, launching Plaid Link.
class LinkAccountButton extends ConsumerStatefulWidget {
  const LinkAccountButton({super.key});

  @override
  ConsumerState<LinkAccountButton> createState() => _LinkAccountButtonState();
}

class _LinkAccountButtonState extends ConsumerState<LinkAccountButton> {
  bool _connecting = false;

  Future<void> _launch() async {
    if (!ref.read(isProProvider)) {
      final upgraded = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      if (upgraded != true) return;
      ref.invalidate(purchaseProductsProvider);
    }

    setState(() => _connecting = true);
    try {
      await ref.read(plaidServiceProvider).openLink(
        onSuccess: (success) async {
          final institution = success.metadata.institution?.name ?? 'Linked institution';
          await ref.read(plaidServiceProvider).exchangePublicToken(
                publicToken: success.publicToken,
                institutionName: institution,
              );
          await ref.read(plaidServiceProvider).syncTransactions();
          ref.invalidate(accountsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Account linked')));
          }
        },
        onExit: (exit) {
          if (exit.error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Plaid Link: ${exit.error!.displayMessage ?? exit.error!.message}')),
            );
          }
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t open Plaid Link: $e')));
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(isProProvider);
    return CustomPaint(
      painter: _DashedBorderPainter(color: AppColors.border),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _connecting ? null : _launch,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: _connecting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, color: AppColors.accentBlue),
                        const SizedBox(width: 8),
                        const Text('Add an account', style: TextStyle(color: AppColors.accentBlue)),
                        if (!isPro) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: AppColors.accentBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;
  static const _radius = 14.0;
  static const _dashWidth = 6.0;
  static const _dashGap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      const Radius.circular(_radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dashWidth).clamp(0, metric.length).toDouble();
        dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + _dashGap;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}
