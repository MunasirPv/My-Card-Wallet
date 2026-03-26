import 'package:my_card_wallet/features/cards/domain/entities/card_entity.dart';

abstract class CardRepository {
  Future<List<CardEntity>> getAllCards();
  Future<CardEntity?> getCardById(String id);
  Future<void> saveCard(CardEntity card);
  Future<void> updateCard(CardEntity card);
  Future<void> deleteCard(String id);
  Future<void> deleteAllCards();
  /// Returns decrypted card number for the given card ID.
  Future<String> revealCardNumber(String cardId);
  /// Returns decrypted CVV for the given card ID.
  Future<String> revealCVV(String cardId);
}
