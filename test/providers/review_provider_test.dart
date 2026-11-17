import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:learn_flashcards/models/flashcard.dart';
import 'package:learn_flashcards/providers/review_provider.dart';
import 'package:learn_flashcards/services/storage_service.dart';

class _MockStorageService extends StorageService {
  final List<Id> deletedCardIds = [];
  final List<Flashcard> savedCards = [];

  @override
  Future<void> deleteCard(Id cardId) async {
    deletedCardIds.add(cardId);
  }

  @override
  Future<void> saveCard(Flashcard card) async {
    savedCards.add(card);
  }
}

void main() {
  group('ReviewProvider - File d\'attente & Ordonnancement', () {
    test('Trie par urgence FSRS (dueDate la plus ancienne en premier) par défaut', () {
      final t1 = DateTime(2026, 11, 11, 8, 0);
      final t2 = DateTime(2026, 11, 11, 9, 0);
      final t3 = DateTime(2026, 11, 11, 10, 0);

      final card1 = Flashcard()..id = 1..front = 'Q1'..back = 'A1'..dueDate = t2;
      final card2 = Flashcard()..id = 2..front = 'Q2'..back = 'A2'..dueDate = t1;
      final card3 = Flashcard()..id = 3..front = 'Q3'..back = 'A3'..dueDate = t3;

      final provider = ReviewProvider();
      provider.initSession(
        cards: [card1, card2, card3],
        isRandomOrder: false,
      );

      expect(provider.reviewQueue.length, 3);
      expect(provider.reviewQueue[0].id, 2); // t1 (8h)
      expect(provider.reviewQueue[1].id, 1); // t2 (9h)
      expect(provider.reviewQueue[2].id, 3); // t3 (10h)
    });

    test('Une carte notée 1 (Again) est remise à la fin de la file de la session en cours', () {
      final card1 = Flashcard()..id = 1..front = 'Q1'..back = 'A1'..dueDate = DateTime.now();
      final card2 = Flashcard()..id = 2..front = 'Q2'..back = 'A2'..dueDate = DateTime.now();

      final provider = ReviewProvider();
      provider.initSession(cards: [card1, card2]);

      expect(provider.currentCard?.id, 1);
      provider.rateCurrentCard(rating: 1, isIntensiveMinutes: true);

      // Card 1 a été repoussée en fin de file
      expect(provider.reviewQueue.length, 3);
      expect(provider.reviewQueue[2].id, 1);
      expect(provider.currentCard?.id, 2);
    });

    test('toggleRandomOrder bascule l\'ordre aléatoire en direct sans changer la carte courante', () {
      final card1 = Flashcard()..id = 1..front = 'Q1'..back = 'A1'..dueDate = DateTime(2026, 11, 11, 8, 0);
      final card2 = Flashcard()..id = 2..front = 'Q2'..back = 'A2'..dueDate = DateTime(2026, 11, 11, 9, 0);
      final card3 = Flashcard()..id = 3..front = 'Q3'..back = 'A3'..dueDate = DateTime(2026, 11, 11, 10, 0);

      final provider = ReviewProvider();
      provider.initSession(cards: [card1, card2, card3], isRandomOrder: false);

      expect(provider.isRandomOrder, isFalse);
      expect(provider.currentCard?.id, 1);

      provider.toggleRandomOrder();
      expect(provider.isRandomOrder, isTrue);
      // La carte courante reste card1
      expect(provider.currentCard?.id, 1);
      expect(provider.reviewQueue.length, 3);

      provider.toggleRandomOrder();
      expect(provider.isRandomOrder, isFalse);
      expect(provider.currentCard?.id, 1);
    });
  });

  group('ReviewProvider - Générateur de Distracteurs QCM', () {
    test('Génère 4 choix uniques comprenant la bonne réponse et 3 distracteurs', () {
      final card1 = Flashcard()..id = 1..front = 'cos(0)'..back = '1';
      final card2 = Flashcard()..id = 2..front = 'sin(0)'..back = '0';
      final card3 = Flashcard()..id = 3..front = 'tan(pi/4)'..back = '1'; // doublon de réponse volontaire
      final card4 = Flashcard()..id = 4..front = 'sin(pi/2)'..back = '1';
      final card5 = Flashcard()..id = 5..front = 'cos(pi)'..back = '-1';
      final card6 = Flashcard()..id = 6..front = 'sin(pi/6)'..back = '1/2';

      final provider = ReviewProvider();
      provider.initSession(cards: [card1, card2, card3, card4, card5, card6]);

      final choices = provider.generateQcmChoices(currentCard: card1, allPoolCards: [card1, card2, card3, card4, card5, card6]);

      expect(choices.length, 4);
      expect(choices.contains('1'), isTrue); // Contient la bonne réponse
      expect(choices.toSet().length, 4);    // Tous les choix sont uniques
    });

    test('Complète les distracteurs avec le pool global si le paquet contient moins de 4 réponses', () {
      final cardA = Flashcard()..id = 1..front = 'A'..back = 'AnsA';
      final cardB = Flashcard()..id = 2..front = 'B'..back = 'AnsB';

      final external1 = Flashcard()..id = 10..front = 'X'..back = 'AnsX';
      final external2 = Flashcard()..id = 11..front = 'Y'..back = 'AnsY';

      final provider = ReviewProvider();
      provider.initSession(cards: [cardA, cardB]);

      final choices = provider.generateQcmChoices(
        currentCard: cardA,
        allPoolCards: [cardA, cardB, external1, external2],
      );

      expect(choices.length, 4);
      expect(choices.contains('AnsA'), isTrue);
      expect(choices.toSet().length, 4);
    });
  });

  group('ReviewProvider - Navigation Précédente / Suivante', () {
    test('Navigation fluide entre cartes avec canGoPrevious et canGoNext', () {
      final card1 = Flashcard()..id = 1..front = 'Q1'..back = 'A1';
      final card2 = Flashcard()..id = 2..front = 'Q2'..back = 'A2';
      final card3 = Flashcard()..id = 3..front = 'Q3'..back = 'A3';

      final provider = ReviewProvider();
      provider.initSession(cards: [card1, card2, card3]);

      // Sur la 1ère carte
      expect(provider.currentIndex, 0);
      expect(provider.canGoPrevious, isFalse);
      expect(provider.canGoNext, isTrue);

      // Avance à la 2ème carte
      provider.nextCard();
      expect(provider.currentIndex, 1);
      expect(provider.canGoPrevious, isTrue);
      expect(provider.canGoNext, isTrue);

      // Avance à la 3ème carte (dernière)
      provider.nextCard();
      expect(provider.currentIndex, 2);
      expect(provider.canGoPrevious, isTrue);
      expect(provider.canGoNext, isFalse);

      // Depuis la dernière carte, recule à la 2ème carte
      provider.previousCard();
      expect(provider.currentIndex, 1);
      expect(provider.canGoPrevious, isTrue);
      expect(provider.canGoNext, isTrue);

      // Re-avance à la dernière carte
      provider.nextCard();
      expect(provider.currentIndex, 2);
      expect(provider.currentCard?.id, 3);
    });
  });

  group('ReviewProvider - Suppression de la Carte Courante', () {
    test('deleteCurrentCard supprime de storage et de la file de révision', () async {
      final mockStorage = _MockStorageService();
      final card1 = Flashcard()..id = 101..front = 'Q1'..back = 'A1';
      final card2 = Flashcard()..id = 102..front = 'Q2'..back = 'A2';
      final card3 = Flashcard()..id = 103..front = 'Q3'..back = 'A3';

      final provider = ReviewProvider();
      provider.initSession(cards: [card1, card2, card3]);

      // Supprimer la première carte (101)
      await provider.deleteCurrentCard(storage: mockStorage);
      expect(mockStorage.deletedCardIds, [101]);
      expect(provider.reviewQueue.length, 2);
      expect(provider.currentCard?.id, 102);

      // Avancer sur la dernière carte (103) et la supprimer
      provider.nextCard();
      expect(provider.currentCard?.id, 103);
      await provider.deleteCurrentCard(storage: mockStorage);
      expect(mockStorage.deletedCardIds, [101, 103]);
      expect(provider.reviewQueue.length, 1);
      // Index replacé sur la dernière restante (102)
      expect(provider.currentCard?.id, 102);

      // Supprimer la seule restante
      await provider.deleteCurrentCard(storage: mockStorage);
      expect(provider.reviewQueue.isEmpty, isTrue);
      expect(provider.isSessionFinished, isTrue);
    });
  });

  group('ReviewProvider - Édition de la Carte Courante', () {
    test('updateCurrentCard met à jour recto et verso, persiste et notifie', () async {
      final mockStorage = _MockStorageService();
      final card1 = Flashcard()..id = 201..front = 'Ancienne Question'..back = 'Ancienne Réponse';
      final card2 = Flashcard()..id = 202..front = 'Q2'..back = 'A2';

      final provider = ReviewProvider();
      provider.initSession(cards: [card1, card2]);

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.updateCurrentCard(
        front: 'Nouvelle Question Corrigée',
        back: 'Nouvelle Réponse Détaillée',
        storage: mockStorage,
      );

      expect(provider.currentCard?.front, 'Nouvelle Question Corrigée');
      expect(provider.currentCard?.back, 'Nouvelle Réponse Détaillée');
      expect(mockStorage.savedCards.length, 1);
      expect(mockStorage.savedCards.first.id, 201);
      expect(mockStorage.savedCards.first.front, 'Nouvelle Question Corrigée');
      expect(mockStorage.savedCards.first.back, 'Nouvelle Réponse Détaillée');
      expect(provider.currentIndex, 0);
      expect(provider.reviewQueue.length, 2);
      expect(notified, isTrue);
    });
  });
}
