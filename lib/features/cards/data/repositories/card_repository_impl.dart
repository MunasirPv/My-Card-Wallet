import 'package:my_card_wallet/features/cards/data/datasources/card_local_datasource.dart';
import 'package:my_card_wallet/features/cards/domain/entities/card_entity.dart';
import 'package:my_card_wallet/features/cards/domain/repositories/card_repository.dart';

class CardRepositoryImpl implements CardRepository {
  final CardLocalDataSource _dataSource;

  CardRepositoryImpl(this._dataSource);

  @override
  Future<List<CardEntity>> getAllCards() => _dataSource.getAllCards();

  @override
  Future<CardEntity?> getCardById(String id) => _dataSource.getCardById(id);

  @override
  Future<void> saveCard(CardEntity card) => _dataSource.saveCard(card);

  @override
  Future<void> updateCard(CardEntity card) => _dataSource.updateCard(card);

  @override
  Future<void> deleteCard(String id) => _dataSource.deleteCard(id);

  @override
  Future<void> deleteAllCards() => _dataSource.deleteAllCards();

  @override
  Future<String> revealCardNumber(String cardId) =>
      _dataSource.revealCardNumber(cardId);

  @override
  Future<String> revealCVV(String cardId) => _dataSource.revealCVV(cardId);
}
