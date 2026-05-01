import 'package:flutter/material.dart';

import '../../state/premium_state.dart';

class PremiumPaywallDialog extends StatelessWidget {
  const PremiumPaywallDialog({super.key, required this.premiumState});

  final PremiumState premiumState;

  static Future<void> show(
    BuildContext context,
    PremiumState premiumState,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PremiumPaywallDialog(premiumState: premiumState),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: premiumState,
      builder: (context, _) {
        final isLoading = premiumState.isLoading;
        final error = premiumState.errorMessage;

        return AlertDialog(
          title: const Text('Premium Abonelik'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ücretsiz planda yalnızca 1 çizelge oluşturabilirsiniz.',
              ),
              const SizedBox(height: 12),
              const _BenefitRow(text: 'Sınırsız çizelge'),
              const _BenefitRow(text: 'Reklamlara karşı PDF dışa aktarım'),
              const SizedBox(height: 12),
              const Text(
                'Aylık premium abonelik ile tüm özelliklere erişin.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
              if (isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
          actions: [
            TextButton(
              key: const Key('paywall-cancel'),
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              key: const Key('paywall-restore'),
              onPressed: isLoading
                  ? null
                  : () async {
                      await premiumState.restorePurchases();
                      if (context.mounted && premiumState.isPremium) {
                        Navigator.of(context).pop();
                      }
                    },
              child: const Text('Satın alımı geri yükle'),
            ),
            FilledButton(
              key: const Key('paywall-buy'),
              onPressed: isLoading
                  ? null
                  : () async {
                      await premiumState.buyPremium();
                      if (context.mounted && premiumState.isPremium) {
                        Navigator.of(context).pop();
                      }
                    },
              child: const Text('Premium Ol'),
            ),
          ],
        );
      },
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
