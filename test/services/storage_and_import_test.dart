import 'package:flutter_test/flutter_test.dart';
import 'package:learn_flashcards/models/deck.dart';
import 'package:learn_flashcards/models/flashcard.dart';
import 'package:learn_flashcards/providers/deck_provider.dart';
import 'package:learn_flashcards/services/storage_service.dart';

void main() {
  group('StorageService & Import CSV', () {
    test('addCardsToDeck ajoute bien les cartes au paquet et les conserve', () async {
      final storage = StorageService();
      final deck = await storage.createDeck('Allemand');

      final card1 = Flashcard()..front = 'Hund'..back = 'Chien';
      final card2 = Flashcard()..front = 'Katze'..back = 'Chat';

      await storage.addCardsToDeck([card1, card2], deck);

      final cards = await storage.getCardsForDeck(deck.id);
      expect(cards.length, 2);
      expect(cards.map((c) => c.front), containsAll(['Hund', 'Katze']));
      expect(deck.allCards.length, 2);
    });

    test('DeckProvider.importCsv ajoute les cartes et met à jour le paquet', () async {
      final storage = StorageService();
      final provider = DeckProvider(storage);
      await provider.loadDecks();

      final deck = await provider.createDeck('Espagnol');
      const csv = "perro,chien\ngato,chat\ncasa,maison";

      final count = await provider.importCsv(deck: deck, csvContent: csv);
      expect(count, 3);

      final updatedDeck = provider.decks.firstWhere((d) => d.id == deck.id);
      expect(updatedDeck.allCards.length, 3);
      expect(updatedDeck.allCards.map((c) => c.front), containsAll(['perro', 'gato', 'casa']));
    });

    test('DeckProvider.switchDeckMode bascule bien le mode du paquet de Colles vers Long Terme', () async {
      final storage = StorageService();
      final provider = DeckProvider(storage);
      await provider.loadDecks();

      final deck = await provider.createDeck('Test Mode', mode: FsrsMode.intensiveMinutes);
      expect(deck.mode, FsrsMode.intensiveMinutes);

      await provider.switchDeckMode(deck, FsrsMode.longTermDays);

      final updated = provider.decks.firstWhere((d) => d.id == deck.id);
      expect(updated.mode, FsrsMode.longTermDays);
      expect(deck.mode, FsrsMode.longTermDays);
    });
  });
}
