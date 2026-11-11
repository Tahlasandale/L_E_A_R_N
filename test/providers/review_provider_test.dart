import 'package:flutter_test/flutter_test.dart';
import 'package:learn_flashcards/models/flashcard.dart';
import 'package:learn_flashcards/providers/review_provider.dart';

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
}
