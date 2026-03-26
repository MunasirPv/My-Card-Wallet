import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:my_card_wallet/core/security/hce_bridge.dart';
import 'package:my_card_wallet/core/utils/card_utils.dart';
import 'package:my_card_wallet/features/auth/domain/auth_service.dart';
import 'package:my_card_wallet/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_card_wallet/features/cards/domain/entities/card_entity.dart';
import 'package:my_card_wallet/features/cards/presentation/providers/card_providers.dart';

class CardWidget extends ConsumerStatefulWidget {
  final CardEntity card;
  final bool isInteractive;

  const CardWidget({super.key, required this.card, this.isInteractive = true});

  @override
  ConsumerState<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends ConsumerState<CardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _frontAngle;
  late Animation<double> _backAngle;
  bool _isFlipped = false;

  static const _cardWidth = 340.0;
  static const _cardHeight = 210.0;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _frontAngle =
        TweenSequence([
          TweenSequenceItem(
            tween: Tween(begin: 0.0, end: math.pi / 2),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween(begin: math.pi / 2, end: math.pi),
            weight: 50,
          ),
        ]).animate(
          CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
        );

    _backAngle =
        TweenSequence([
          TweenSequenceItem(
            tween: Tween(begin: math.pi, end: math.pi / 2),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween(begin: math.pi / 2, end: 0.0),
            weight: 50,
          ),
        ]).animate(
          CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _onFlip() async {
    if (!widget.isInteractive) return;
    if (!_isFlipped) {
      HapticFeedback.mediumImpact();
      _flipController.forward();
      setState(() => _isFlipped = true);

      // Auto-flip back after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && _isFlipped) _flipBack();
      });
    } else {
      _flipBack();
    }
  }

  void _flipBack() {
    if (!mounted) return;
    _flipController.reverse();
    setState(() => _isFlipped = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onFlip,
      child: SizedBox(
        width: _cardWidth,
        height: _cardHeight,
        child: Stack(
          children: [
            // Front face
            AnimatedBuilder(
              animation: _frontAngle,
              builder: (_, child) => Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(_frontAngle.value),
                alignment: Alignment.center,
                child: _frontAngle.value <= math.pi / 2
                    ? child
                    : const SizedBox.shrink(),
              ),
              child: _CardFront(card: widget.card),
            ),
            // Back face
            AnimatedBuilder(
              animation: _backAngle,
              builder: (_, child) => Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(_backAngle.value),
                alignment: Alignment.center,
                child: _backAngle.value <= math.pi / 2
                    ? child
                    : const SizedBox.shrink(),
              ),
              child: _CardBack(card: widget.card),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card Front ────────────────────────────────────────────────────────────────

class _CardFront extends ConsumerWidget {
  final CardEntity card;
  const _CardFront({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = CardUtils.networkGradient(card.network);

    return RepaintBoundary(
      child: Container(
        width: 340,
        height: 210,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            // Card content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: bank name + chip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        card.bankName ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      _ChipIcon(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Card number
                  _CardNumberDisplay(card: card),
                  const Spacer(),
                  // Hint
                  Text(
                    'tap card to flip',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Bottom row: holder name, expiry, network logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CARD HOLDER',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            card.holderName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXPIRES',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            card.expiryDisplay,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      _NetworkLogo(network: card.network),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardNumberDisplay extends ConsumerStatefulWidget {
  final CardEntity card;

  const _CardNumberDisplay({required this.card});

  @override
  ConsumerState<_CardNumberDisplay> createState() => _CardNumberDisplayState();
}

class _CardNumberDisplayState extends ConsumerState<_CardNumberDisplay> {
  Future<void> _toggleReveal() async {
    final current =
        ref.read(revealedCardsProvider)[widget.card.id] ?? const RevealState();

    if (current.numberRevealed) {
      // Mask it
      ref.read(revealedCardsProvider.notifier).state = {
        ...ref.read(revealedCardsProvider),
        widget.card.id: current.copyWith(
          numberRevealed: false,
          decryptedNumber: null,
        ),
      };
      return;
    }
    // Auth to reveal
    final authService = ref.read(authServiceProvider);
    var result = await authService.authenticateForSensitiveAction(
      reason: 'Authenticate to reveal card number',
    );

    if (result != AuthResult.success) {
      // Fallback to PIN dialog
      final pinVerified = await _showPinDialog(context, ref);
      if (!pinVerified) return;
      result = AuthResult.success;
    }

    final repo = ref.read(cardRepositoryProvider);
    final number = await repo.revealCardNumber(widget.card.id);
    final currentAfterAuth =
        ref.read(revealedCardsProvider)[widget.card.id] ?? const RevealState();
    ref.read(revealedCardsProvider.notifier).state = {
      ...ref.read(revealedCardsProvider),
      widget.card.id: currentAfterAuth.copyWith(
        numberRevealed: true,
        decryptedNumber: number,
      ),
    };
    // Auto-mask after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        final c =
            ref.read(revealedCardsProvider)[widget.card.id] ??
            const RevealState();
        ref.read(revealedCardsProvider.notifier).state = {
          ...ref.read(revealedCardsProvider),
          widget.card.id: c.copyWith(
            numberRevealed: false,
            decryptedNumber: null,
          ),
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reveal = getRevealState(ref, widget.card.id);
    final displayNumber =
        reveal.numberRevealed && reveal.decryptedNumber != null
        ? CardUtils.formatCardNumber(reveal.decryptedNumber!)
        : widget.card.maskedNumber;

    return GestureDetector(
      onTap: _toggleReveal,
      child: Row(
        children: [
          Text(
            displayNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            reveal.numberRevealed
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: Colors.white54,
            size: 16,
          ),
        ],
      ),
    );
  }
}

// ── Card Back ─────────────────────────────────────────────────────────────────

class _CardBack extends ConsumerStatefulWidget {
  final CardEntity card;
  const _CardBack({required this.card});

  @override
  ConsumerState<_CardBack> createState() => _CardBackState();
}

class _CardBackState extends ConsumerState<_CardBack> {
  bool _isNfcActive = false;

  Future<void> _toggleNfcPayment() async {
    if (_isNfcActive) {
      await HceBridge.deactivateCard();
      setState(() => _isNfcActive = false);
      return;
    }

    final isSupported = await HceBridge.isHceSupported();
    if (!isSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC payment not supported or disabled on this device')),
        );
      }
      return;
    }

    // Auth
    final authService = ref.read(authServiceProvider);
    var result = await authService.authenticateForSensitiveAction(
      reason: 'Authenticate to enable NFC payment',
    );

    if (result != AuthResult.success) {
      final pinVerified = await _showPinDialog(context, ref);
      if (!pinVerified) return;
    }

    // Get PAN
    final repo = ref.read(cardRepositoryProvider);
    final number = await repo.revealCardNumber(widget.card.id);

    final success = await HceBridge.activateCard(
      number: number,
      expiry: widget.card.expiryDisplay,
      name: widget.card.holderName,
    );

    if (success) {
      setState(() => _isNfcActive = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NFC Payment Active for 30 seconds'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      Future.delayed(const Duration(seconds: 30), () async {
        await HceBridge.deactivateCard();
        if (mounted) setState(() => _isNfcActive = false);
      });
    }
  }

  Future<void> _toggleCVV() async {
    final current =
        ref.read(revealedCardsProvider)[widget.card.id] ?? const RevealState();

    if (current.cvvRevealed) {
      ref.read(revealedCardsProvider.notifier).state = {
        ...ref.read(revealedCardsProvider),
        widget.card.id: current.copyWith(cvvRevealed: false, decryptedCVV: null),
      };
      return;
    }

    final authService = ref.read(authServiceProvider);
    var result = await authService.authenticateForSensitiveAction(
      reason: 'Authenticate to view CVV',
    );

    if (result != AuthResult.success) {
      final pinVerified = await _showPinDialog(context, ref);
      if (!pinVerified) return;
      result = AuthResult.success;
    }

    final repo = ref.read(cardRepositoryProvider);
    final cvv = await repo.revealCVV(widget.card.id);

    final currentAfterAuth =
        ref.read(revealedCardsProvider)[widget.card.id] ?? const RevealState();
    ref.read(revealedCardsProvider.notifier).state = {
      ...ref.read(revealedCardsProvider),
      widget.card.id:
          currentAfterAuth.copyWith(cvvRevealed: true, decryptedCVV: cvv),
    };

    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        final c = ref.read(revealedCardsProvider)[widget.card.id] ??
            const RevealState();
        ref.read(revealedCardsProvider.notifier).state = {
          ...ref.read(revealedCardsProvider),
          widget.card.id: c.copyWith(cvvRevealed: false, decryptedCVV: null),
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reveal = getRevealState(ref, widget.card.id);
    final gradient = CardUtils.networkGradient(widget.card.network);

    return Container(
      width: 340,
      height: 210,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradient.last, gradient.first],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          // Magnetic stripe
          Container(height: 44, color: Colors.black87),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Signature strip
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.grey.shade300,
                          Colors.white,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // CVV box
                GestureDetector(
                  onTap: _toggleCVV,
                  child: Container(
                    width: 56,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      reveal.cvvRevealed && reveal.decryptedCVV != null
                          ? reveal.decryptedCVV!
                          : '•••',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'CVV  (tap box to reveal)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (Platform.isAndroid)
                  InkWell(
                    onTap: _toggleNfcPayment,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isNfcActive
                            ? Colors.green.withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isNfcActive
                              ? Colors.greenAccent
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.nfc_rounded,
                            color: _isNfcActive
                                ? Colors.greenAccent
                                : Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isNfcActive ? 'ACTIVE' : 'NFC PAY',
                            style: TextStyle(
                              color: _isNfcActive
                                  ? Colors.greenAccent
                                  : Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ).animate(target: _isNfcActive ? 1 : 0)
                     .shimmer(duration: 1500.ms, color: Colors.white24),
                  ),
                const Spacer(),
                _NetworkLogo(network: widget.card.network),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Sub-widgets ────────────────────────────────────────────────────────

class _ChipIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFFAD961)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(painter: _ChipPainter()),
    );
  }
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown.shade700.withOpacity(0.5)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    // Simplified chip lines
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 5, size.width - 12, size.height - 10),
        const Radius.circular(3),
      ),
      paint,
    );
    canvas.drawLine(
      Offset(size.width / 2, 5),
      Offset(size.width / 2, size.height - 5),
      paint,
    );
    canvas.drawLine(
      Offset(6, size.height / 2),
      Offset(size.width - 6, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _NetworkLogo extends StatelessWidget {
  final CardNetwork network;
  const _NetworkLogo({required this.network});

  @override
  Widget build(BuildContext context) {
    return switch (network) {
      CardNetwork.visa => const Text(
        'VISA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 1.0,
          height: 1.4,
          leadingDistribution: TextLeadingDistribution.even,
          textBaseline: TextBaseline.alphabetic,
        ),
      ),
      CardNetwork.mastercard => SizedBox(
        width: 44,
        height: 28,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEB001B),
                ),
              ),
            ),
            Positioned(
              left: 16,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF79E1B).withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      ),
      CardNetwork.amex => const Text(
        'AMEX',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      _ => Text(
        CardUtils.networkLabel(network),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    };
  }
}

Future<bool> _showPinDialog(BuildContext context, WidgetRef ref) async {
  final theme = Theme.of(context);
  String? error;
  bool isLoading = false;

  final defaultPinTheme = PinTheme(
    width: 48,
    height: 56,
    textStyle: theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.bold,
    ),
    decoration: BoxDecoration(
      border: Border.all(color: theme.colorScheme.outline),
      borderRadius: BorderRadius.circular(12),
    ),
  );

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 48,
                  color: theme.colorScheme.primary,
                ).animate().fadeIn().scale(begin: const Offset(0.7, 0.7)),
                const SizedBox(height: 24),
                Text(
                  'Enter PIN',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verify it\'s you to reveal details',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Pinput(
                  length: 6,
                  obscureText: true,
                  autofocus: true,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(
                      color: theme.colorScheme.error,
                      width: 2,
                    ),
                  ),
                  onCompleted: (pin) async {
                    setState(() => isLoading = true);
                    final auth = ref.read(authServiceProvider);
                    final ok = await auth.verifyPIN(pin);
                    if (!ctx.mounted) return;
                    if (ok) {
                      Navigator.pop(ctx, true);
                    } else {
                      setState(() {
                        isLoading = false;
                        error = 'Incorrect PIN';
                      });
                    }
                  },
                  hapticFeedbackType: HapticFeedbackType.lightImpact,
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ).animate().shake(duration: 400.ms),
                ],
                if (isLoading) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  return result ?? false;
}
