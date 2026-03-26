import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_card_wallet/core/security/session_manager.dart';
import 'package:my_card_wallet/features/auth/domain/auth_service.dart';
import 'package:my_card_wallet/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_card_wallet/features/auth/presentation/screens/pin_screen.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometric on screen appearance
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.authenticateWithBiometrics();

    if (!mounted) return;
    setState(() => _isAuthenticating = false);

    if (result == AuthResult.success) {
      ref.read(isAuthenticatedProvider.notifier).state = true;
      ref.read(sessionManagerProvider.notifier).onAuthenticated();
    } else if (result == AuthResult.biometricUnavailable ||
        result == AuthResult.notSetup) {
      _showPINFallback();
    } else {
      setState(() => _errorMessage = 'Authentication failed. Try again.');
    }
  }

  void _showPINFallback() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PinScreen(isSetup: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.5, 0.5)),
              const SizedBox(height: 32),
              Text(
                'Card Wallet',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'Your cards, secured.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 56),
              if (_isAuthenticating)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    FilledButton.icon(
                      onPressed: _tryBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Authenticate'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 52),
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _showPINFallback,
                      child: const Text('Use PIN instead'),
                    ).animate().fadeIn(delay: 500.ms),
                  ],
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ).animate().shake(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
