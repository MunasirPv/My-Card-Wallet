import 'package:flutter_test/flutter_test.dart';
import 'package:my_card_wallet/core/utils/card_utils.dart';

void main() {
  group('CardUtils', () {
    test('detects Visa card', () {
      expect(CardUtils.detectNetwork('4111111111111111'), CardNetwork.visa);
    });

    test('detects Mastercard', () {
      expect(CardUtils.detectNetwork('5500005555555559'), CardNetwork.mastercard);
    });

    test('detects Amex', () {
      expect(CardUtils.detectNetwork('378282246310005'), CardNetwork.amex);
    });

    test('validates Luhn checksum', () {
      expect(CardUtils.isValidCardNumber('4111111111111111'), isTrue);
      expect(CardUtils.isValidCardNumber('1234567890123456'), isFalse);
    });

    test('masks card number correctly', () {
      final masked = CardUtils.maskCardNumber('4111111111111111');
      expect(masked, '•••• •••• •••• 1111');
    });

    test('formats card number in groups of 4', () {
      final formatted = CardUtils.formatCardNumber('4111111111111111');
      expect(formatted, '4111 1111 1111 1111');
    });

    test('validates expiry', () {
      // Future date
      final now = DateTime.now();
      final futureMonth = ((now.month % 12) + 1).toString().padLeft(2, '0');
      final futureYear = (now.year + 1 - 2000).toString();
      expect(CardUtils.isValidExpiry(futureMonth, futureYear), isTrue);

      // Past date
      expect(CardUtils.isValidExpiry('01', '20'), isFalse);
    });
  });
}
