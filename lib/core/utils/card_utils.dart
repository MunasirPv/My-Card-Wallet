import 'package:flutter/material.dart';

enum CardNetwork { visa, mastercard, amex, discover, rupay, maestro, unknown }

class CardUtils {
  /// Luhn algorithm validation
  static bool isValidCardNumber(String number) {
    final sanitized = number.replaceAll(RegExp(r'\D'), '');
    if (sanitized.length < 13 || sanitized.length > 19) return false;

    int sum = 0;
    bool alternate = false;
    for (int i = sanitized.length - 1; i >= 0; i--) {
      int n = int.parse(sanitized[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  static CardNetwork detectNetwork(String number) {
    final sanitized = number.replaceAll(RegExp(r'\D'), '');
    if (sanitized.startsWith('4')) return CardNetwork.visa;
    if (RegExp(r'^5[1-5]').hasMatch(sanitized) ||
        RegExp(r'^2(2[2-9][1-9]|[3-6]\d{2}|7[01]\d|720)').hasMatch(sanitized)) {
      return CardNetwork.mastercard;
    }
    if (RegExp(r'^3[47]').hasMatch(sanitized)) return CardNetwork.amex;
    if (RegExp(r'^6(?:011|5)').hasMatch(sanitized)) return CardNetwork.discover;
    if (RegExp(r'^(508[5-9]|6069|607|608|6521|6522)').hasMatch(sanitized)) {
      return CardNetwork.rupay;
    }
    if (RegExp(r'^(5018|5020|5038|6304)').hasMatch(sanitized)) {
      return CardNetwork.maestro;
    }
    return CardNetwork.unknown;
  }

  static String formatCardNumber(String number) {
    final sanitized = number.replaceAll(RegExp(r'\D'), '');
    final network = detectNetwork(sanitized);
    // Amex: 4-6-5 format
    if (network == CardNetwork.amex && sanitized.length >= 4) {
      final parts = [
        sanitized.substring(0, sanitized.length > 4 ? 4 : sanitized.length),
        if (sanitized.length > 4)
          sanitized.substring(4, sanitized.length > 10 ? 10 : sanitized.length),
        if (sanitized.length > 10) sanitized.substring(10),
      ];
      return parts.join(' ');
    }
    // Standard 4-4-4-4
    final buffer = StringBuffer();
    for (int i = 0; i < sanitized.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(sanitized[i]);
    }
    return buffer.toString();
  }

  static String maskCardNumber(String number) {
    final sanitized = number.replaceAll(RegExp(r'\D'), '');
    if (sanitized.length < 4) return '•••• •••• •••• ••••';
    final last4 = sanitized.substring(sanitized.length - 4);
    return '•••• •••• •••• $last4';
  }

  static String getLastFour(String number) {
    final sanitized = number.replaceAll(RegExp(r'\D'), '');
    if (sanitized.length < 4) return '????';
    return sanitized.substring(sanitized.length - 4);
  }

  static bool isValidExpiry(String month, String year) {
    final m = int.tryParse(month);
    final y = int.tryParse(year);
    if (m == null || y == null) return false;
    if (m < 1 || m > 12) return false;
    final now = DateTime.now();
    final fullYear = y < 100 ? 2000 + y : y;
    final expiry = DateTime(fullYear, m + 1);
    return expiry.isAfter(now);
  }

  static bool isValidCVV(String cvv, CardNetwork network) {
    final sanitized = cvv.replaceAll(RegExp(r'\D'), '');
    return network == CardNetwork.amex
        ? sanitized.length == 4
        : sanitized.length == 3;
  }

  static Color networkColor(CardNetwork network) {
    return switch (network) {
      CardNetwork.visa => const Color(0xFF1A1F71),
      CardNetwork.mastercard => const Color(0xFFEB001B),
      CardNetwork.amex => const Color(0xFF007BC1),
      CardNetwork.discover => const Color(0xFFFF6600),
      CardNetwork.rupay => const Color(0xFF006A4E),
      CardNetwork.maestro => const Color(0xFF004A97),
      CardNetwork.unknown => const Color(0xFF424242),
    };
  }

  static List<Color> networkGradient(CardNetwork network) {
    return switch (network) {
      CardNetwork.visa => [const Color(0xFF1A237E), const Color(0xFF283593)],
      CardNetwork.mastercard => [
          const Color(0xFF880E4F),
          const Color(0xFFAD1457)
        ],
      CardNetwork.amex => [const Color(0xFF006064), const Color(0xFF00838F)],
      CardNetwork.discover => [
          const Color(0xFFE65100),
          const Color(0xFFF57C00)
        ],
      CardNetwork.rupay => [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
      CardNetwork.maestro => [
          const Color(0xFF0D47A1),
          const Color(0xFF1565C0)
        ],
      CardNetwork.unknown => [
          const Color(0xFF212121),
          const Color(0xFF424242)
        ],
    };
  }

  static String networkLabel(CardNetwork network) {
    return switch (network) {
      CardNetwork.visa => 'VISA',
      CardNetwork.mastercard => 'Mastercard',
      CardNetwork.amex => 'AMEX',
      CardNetwork.discover => 'Discover',
      CardNetwork.rupay => 'RuPay',
      CardNetwork.maestro => 'Maestro',
      CardNetwork.unknown => '',
    };
  }
}
