import 'package:my_card_wallet/core/utils/card_utils.dart';

class ScannedCardData {
  final String? cardNumber;
  final String? holderName;
  final String? expiryMonth;
  final String? expiryYear;
  final CardNetwork network;

  const ScannedCardData({
    this.cardNumber,
    this.holderName,
    this.expiryMonth,
    this.expiryYear,
    this.network = CardNetwork.unknown,
  });

  bool get hasUsefulData =>
      cardNumber != null || expiryMonth != null || holderName != null;
}

class CardOCRParser {
  // 13–19 digit card number, optionally separated by spaces or dashes
  static final _cardNumberRegex =
      RegExp(r'\b(\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{0,7})\b');

  // MM/YY or MM/YYYY
  static final _expiryRegex =
      RegExp(r'\b(0[1-9]|1[0-2])[\/\-\s](\d{2}|\d{4})\b');

  // All-caps name: 2–3 words, letters and spaces only, 5–26 chars total
  // Avoids matching "VALID THRU", "GOOD THRU", "DEBIT", "CREDIT", etc.
  static final _nameRegex = RegExp(
    r'\b([A-Z]{2,}(?:\s[A-Z]{2,}){1,2})\b',
  );

  static final _ignoreWords = {
    'VALID', 'THRU', 'GOOD', 'DEBIT', 'CREDIT', 'CARD', 'BANK',
    'MEMBER', 'SINCE', 'VISA', 'AMEX', 'MASTER', 'MASTERCARD',
    'RUPAY', 'DISCOVER', 'MAESTRO', 'PLATINUM', 'GOLD', 'CLASSIC',
    'INTERNATIONAL', 'AUTHORIZED', 'SIGNATURE', 'EXPIRES', 'EXPIRY',
  };

  static ScannedCardData parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final fullText = lines.join(' ');

    // ── Card Number ────────────────────────────────────────────────────────
    String? cardNumber;
    for (final match in _cardNumberRegex.allMatches(fullText)) {
      final digits = match.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 13 && CardUtils.isValidCardNumber(digits)) {
        cardNumber = digits;
        break;
      }
    }

    // ── Expiry ─────────────────────────────────────────────────────────────
    String? expiryMonth;
    String? expiryYear;
    final expiryMatch = _expiryRegex.firstMatch(fullText);
    if (expiryMatch != null) {
      expiryMonth = expiryMatch.group(1);
      final rawYear = expiryMatch.group(2)!;
      // Normalise to 2-digit year
      expiryYear = rawYear.length == 4 ? rawYear.substring(2) : rawYear;
    }

    // ── Holder Name ────────────────────────────────────────────────────────
    String? holderName;
    for (final match in _nameRegex.allMatches(fullText)) {
      final candidate = match.group(0)!;
      final words = candidate.split(' ');
      // Skip if any word is a known non-name token
      if (words.any((w) => _ignoreWords.contains(w))) continue;
      // Must be at least 2 words, total 5+ chars
      if (words.length >= 2 && candidate.length >= 5) {
        holderName = candidate;
        break;
      }
    }

    final network = cardNumber != null
        ? CardUtils.detectNetwork(cardNumber)
        : CardNetwork.unknown;

    return ScannedCardData(
      cardNumber: cardNumber,
      holderName: holderName,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      network: network,
    );
  }
}
