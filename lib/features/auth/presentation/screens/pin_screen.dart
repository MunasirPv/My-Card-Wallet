import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_card_wallet/core/security/session_manager.dart';
import 'package:my_card_wallet/features/auth/presentation/providers/auth_providers.dart';
import 'package:pinput/pinput.dart';

class PinScreen extends ConsumerStatefulWidget {
  final bool isSetup;
  final VoidCallback? onSuccess;

  const PinScreen({super.key, required this.isSetup, this.onSuccess});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _firstPin;
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onPinCompleted(String pin) async {
    final authService = ref.read(authServiceProvider);

    if (widget.isSetup) {
      if (_firstPin == null) {
        setState(() {
          _firstPin = pin;
          _pinController.clear();
        });
        return;
      }
      if (_firstPin != pin) {
        setState(() {
          _error = 'PINs do not match. Try again.';
          _firstPin = null;
          _pinController.clear();
        });
        return;
      }
      setState(() => _isLoading = true);
      await authService.setPIN(pin);
      await authService.setBiometricEnabled(
        await authService.isBiometricAvailable(),
      );
      await authService.completeFirstLaunch();
      if (!mounted) return;
      setState(() => _isLoading = false);
      ref.read(isAuthenticatedProvider.notifier).state = true;
      ref.read(sessionManagerProvider.notifier).onAuthenticated();
      widget.onSuccess?.call();
      if (Navigator.canPop(context)) Navigator.pop(context);
    } else {
      setState(() => _isLoading = true);
      final valid = await authService.verifyPIN(pin);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (valid) {
        ref.read(pinAttemptsProvider.notifier).state = 0;
        ref.read(isAuthenticatedProvider.notifier).state = true;
        ref.read(sessionManagerProvider.notifier).onAuthenticated();
        widget.onSuccess?.call();
        if (Navigator.canPop(context)) Navigator.pop(context);
      } else {
        final attempts = ref.read(pinAttemptsProvider);
        ref.read(pinAttemptsProvider.notifier).state = attempts + 1;
        setState(() {
          _error = 'Incorrect PIN. ${5 - (attempts + 1)} attempts remaining.';
          _pinController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfirming = widget.isSetup && _firstPin != null;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 64,
      textStyle: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Scaffold(
      appBar: widget.isSetup
          ? AppBar(
              title: const Text('Set up PIN'),
              automaticallyImplyLeading: false,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isSetup ? Icons.lock_open_rounded : Icons.lock_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ).animate().fadeIn().scale(begin: const Offset(0.7, 0.7)),
                const SizedBox(height: 32),
                Text(
                  widget.isSetup
                      ? (isConfirming ? 'Confirm your PIN' : 'Create a PIN')
                      : 'Enter your PIN',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isSetup
                      ? (isConfirming
                          ? 'Re-enter the PIN to confirm'
                          : 'This PIN protects access to your wallet')
                      : 'Enter PIN to unlock',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Pinput(
                  length: 6,
                  controller: isConfirming ? _confirmController : _pinController,
                  obscureText: true,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(
                        color: theme.colorScheme.primary, width: 2),
                  ),
                  errorPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(color: theme.colorScheme.error, width: 2),
                  ),
                  onCompleted: _isLoading ? null : _onPinCompleted,
                  hapticFeedbackType: HapticFeedbackType.lightImpact,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ).animate().shake(duration: 400.ms),
                ],
                if (_isLoading) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
