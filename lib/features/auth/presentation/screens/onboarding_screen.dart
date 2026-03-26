import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_card_wallet/features/auth/presentation/screens/pin_screen.dart';

class OnboardingScreen extends ConsumerWidget {
  final VoidCallback? onComplete;
  const OnboardingScreen({super.key, this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.credit_card_rounded,
                    size: 64, color: Colors.white),
              )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(begin: const Offset(0.4, 0.4)),
              const SizedBox(height: 40),
              Text(
                'Card Wallet',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
              const SizedBox(height: 16),
              Text(
                'Your cards, always with you.\nSecured with military-grade encryption.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 48),
              _FeatureRow(
                icon: Icons.lock_rounded,
                label: 'AES-256 encrypted storage',
              ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.3),
              const SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.fingerprint,
                label: 'Biometric authentication',
              ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.3),
              const SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.visibility_off_rounded,
                label: 'Masked card details by default',
              ).animate().fadeIn(delay: 800.ms).slideX(begin: -0.3),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => PinScreen(
                      isSetup: true,
                      onSuccess: onComplete,
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Get Started', style: TextStyle(fontSize: 16)),
              ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.3),
              const SizedBox(height: 24),
              Text(
                'All data is stored locally on your device.\nNothing is ever sent to any server.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 1000.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),
        const SizedBox(width: 16),
        Text(label, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}
