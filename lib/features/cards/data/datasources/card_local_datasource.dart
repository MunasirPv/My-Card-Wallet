import 'dart:convert';

import 'package:my_card_wallet/core/security/encryption_service.dart';
import 'package:my_card_wallet/core/storage/secure_storage_service.dart';
import 'package:my_card_wallet/features/cards/domain/entities/card_entity.dart';

const _cardIndexKey = 'card_index_v1';
const _cardPrefix = 'card_data_v1_';

class CardLocalDataSource {
  final SecureStorageService _storage;
  final EncryptionService _encryption;

  CardLocalDataSource(this._storage, this._encryption);

  Future<List<String>> _getCardIndex() async {
    final raw = await _storage.read(_cardIndexKey);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw) as List);
  }

  Future<void> _saveCardIndex(List<String> ids) async {
    await _storage.write(_cardIndexKey, jsonEncode(ids));
  }

  Future<List<CardEntity>> getAllCards() async {
    final ids = await _getCardIndex();
    final cards = <CardEntity>[];
    for (final id in ids) {
      final card = await _getCardById(id);
      if (card != null) cards.add(card);
    }
    return cards;
  }

  Future<CardEntity?> _getCardById(String id) async {
    final raw = await _storage.read('$_cardPrefix$id');
    if (raw == null) return null;
    return CardEntity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<CardEntity?> getCardById(String id) => _getCardById(id);

  Future<void> saveCard(CardEntity card) async {
    await _storage.write('$_cardPrefix${card.id}', jsonEncode(card.toJson()));
    final ids = await _getCardIndex();
    if (!ids.contains(card.id)) {
      ids.add(card.id);
      await _saveCardIndex(ids);
    }
  }

  Future<void> updateCard(CardEntity card) async {
    await _storage.write('$_cardPrefix${card.id}', jsonEncode(card.toJson()));
  }

  Future<void> deleteCard(String id) async {
    await _storage.delete('$_cardPrefix$id');
    final ids = await _getCardIndex();
    ids.remove(id);
    await _saveCardIndex(ids);
  }

  Future<void> deleteAllCards() async {
    final ids = await _getCardIndex();
    for (final id in ids) {
      await _storage.delete('$_cardPrefix$id');
    }
    await _storage.delete(_cardIndexKey);
  }

  Future<String> revealCardNumber(String cardId) async {
    final card = await _getCardById(cardId);
    if (card == null) throw Exception('Card not found');
    return _encryption.decrypt(card.encryptedNumber, cardId);
  }

  Future<String> revealCVV(String cardId) async {
    final card = await _getCardById(cardId);
    if (card == null) throw Exception('Card not found');
    return _encryption.decrypt(card.encryptedCVV, cardId);
  }
}
