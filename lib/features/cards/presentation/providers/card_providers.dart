import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_card_wallet/core/security/encryption_service.dart';
import 'package:my_card_wallet/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_card_wallet/features/cards/data/datasources/card_local_datasource.dart';
import 'package:my_card_wallet/features/cards/data/repositories/card_repository_impl.dart';
import 'package:my_card_wallet/features/cards/domain/entities/card_entity.dart';
import 'package:my_card_wallet/features/cards/domain/repositories/card_repository.dart';

// ── Infrastructure Providers ────────────────────────────────────────────────

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService(ref.read(secureStorageProvider));
});

final cardDataSourceProvider = Provider<CardLocalDataSource>((ref) {
  return CardLocalDataSource(
    ref.read(secureStorageProvider),
    ref.read(encryptionServiceProvider),
  );
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepositoryImpl(ref.read(cardDataSourceProvider));
});

// ── Cards State Notifier ─────────────────────────────────────────────────────

class CardsNotifier extends AsyncNotifier<List<CardEntity>> {
  @override
  Future<List<CardEntity>> build() => _load();

  Future<List<CardEntity>> _load() async {
    final repo = ref.read(cardRepositoryProvider);
    final cards = await repo.getAllCards();
    // Sort by lastAccessedAt desc, then addedAt desc
    cards.sort((a, b) {
      final aTime = a.lastAccessedAt ?? a.addedAt;
      final bTime = b.lastAccessedAt ?? b.addedAt;
      return bTime.compareTo(aTime);
    });
    return cards;
  }

  Future<void> addCard(CardEntity card) async {
    await ref.read(cardRepositoryProvider).saveCard(card);
    ref.invalidateSelf();
  }

  Future<void> updateCard(CardEntity card) async {
    await ref.read(cardRepositoryProvider).updateCard(card);
    ref.invalidateSelf();
  }

  Future<void> deleteCard(String id) async {
    await ref.read(cardRepositoryProvider).deleteCard(id);
    ref.invalidateSelf();
  }

  Future<void> deleteAllCards() async {
    await ref.read(cardRepositoryProvider).deleteAllCards();
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final cardsProvider = AsyncNotifierProvider<CardsNotifier, List<CardEntity>>(
  CardsNotifier.new,
);

// ── Search & Filter ───────────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((_) => '');
final selectedTagProvider = StateProvider<CardTag?>((_) => null);

final filteredCardsProvider = Provider<AsyncValue<List<CardEntity>>>((ref) {
  final cards = ref.watch(cardsProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final tag = ref.watch(selectedTagProvider);

  return cards.whenData((list) => list.where((c) {
        final matchesQuery = query.isEmpty ||
            c.holderName.toLowerCase().contains(query) ||
            (c.bankName?.toLowerCase().contains(query) ?? false) ||
            c.networkLabel.toLowerCase().contains(query);
        final matchesTag = tag == null || c.tag == tag;
        return matchesQuery && matchesTag;
      }).toList());
});

// ── Reveal State (per-card, auto-masks after 30s) ─────────────────────────────

final revealedCardsProvider =
    StateProvider<Map<String, RevealState>>((_) => {});

class RevealState {
  final bool numberRevealed;
  final bool cvvRevealed;
  final String? decryptedNumber;
  final String? decryptedCVV;

  const RevealState({
    this.numberRevealed = false,
    this.cvvRevealed = false,
    this.decryptedNumber,
    this.decryptedCVV,
  });

  RevealState copyWith({
    bool? numberRevealed,
    bool? cvvRevealed,
    String? decryptedNumber,
    String? decryptedCVV,
  }) =>
      RevealState(
        numberRevealed: numberRevealed ?? this.numberRevealed,
        cvvRevealed: cvvRevealed ?? this.cvvRevealed,
        decryptedNumber: decryptedNumber ?? this.decryptedNumber,
        decryptedCVV: decryptedCVV ?? this.decryptedCVV,
      );
}

RevealState getRevealState(WidgetRef ref, String cardId) {
  return ref.watch(revealedCardsProvider)[cardId] ?? const RevealState();
}
