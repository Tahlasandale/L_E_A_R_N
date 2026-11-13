import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_flashcards/models/deck.dart';
import 'package:learn_flashcards/models/flashcard.dart';
import 'package:learn_flashcards/providers/deck_provider.dart';
import 'package:learn_flashcards/providers/settings_provider.dart';
import 'package:learn_flashcards/services/storage_service.dart';

void main() {
  group('JSON Backup & Restore (Export / Import)', () {
    test('exportFullBackupJson génère un JSON valide avec métriques FSRS et decks', () async {
      final storage = StorageService();
      final deck = await storage.createDeck('Biologie', mode: FsrsMode.intensiveMinutes);
      final card = Flashcard()
        ..front = 'Mitochondrie'
        ..back = 'Centrale énergétique'
        ..reps = 3
        ..interval = 15
        ..ease = 2.4;
      await storage.addCardsToDeck([card], deck);

      final jsonStr = await storage.exportFullBackupJson(extraSettings: {
        'desiredRetention': 0.92,
        'qcmGoodAnswerDuration': 1.5,
      });

      expect(jsonStr, isNotEmpty);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(data['version'], 1);
      expect(data['app'], 'Kawaii Flashcards');
      expect(data['settings']['desiredRetention'], 0.92);
      expect(data['settings']['qcmGoodAnswerDuration'], 1.5);
      expect((data['decks'] as List).length, 1);

      final deckData = (data['decks'] as List).first as Map<String, dynamic>;
      expect(deckData['name'], 'Biologie');
      expect(deckData['mode'], 'intensiveMinutes');
      expect((deckData['cards'] as List).length, 1);

      final cardData = (deckData['cards'] as List).first as Map<String, dynamic>;
      expect(cardData['front'], 'Mitochondrie');
      expect(cardData['back'], 'Centrale énergétique');
      expect(cardData['reps'], 3);
      expect(cardData['ease'], 2.4);
    });

    test('importFullBackupJson importe et merge intelligemment sans doublons', () async {
      final storage = StorageService();
      final provider = DeckProvider(storage);
      await provider.loadDecks();

      // Création d'un premier paquet avec une carte
      final deck = await provider.createDeck('Chimie');
      await provider.addCard(deck: deck, front: 'H2O', back: 'Eau');

      // Préparation d'une sauvegarde avec une mise à jour pour H2O (plus de reps) et une nouvelle carte NaCl
      final backupData = {
        'version': 1,
        'app': 'Kawaii Flashcards',
        'exportDate': DateTime.now().toIso8601String(),
        'decks': [
          {
            'name': 'Chimie',
            'mode': 'intensiveMinutes',
            'isActive': true,
            'cards': [
              {
                'front': 'H2O',
                'back': 'Eau',
                'reps': 5,
                'interval': 30,
                'ease': 2.6,
                'dueDate': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
              },
              {
                'front': 'NaCl',
                'back': 'Sel de table',
                'reps': 1,
                'interval': 1,
                'ease': 2.5,
                'dueDate': DateTime.now().add(const Duration(minutes: 1)).toIso8601String(),
              },
            ],
          },
          {
            'name': 'Physique',
            'mode': 'longTermDays',
            'isActive': true,
            'cards': [
              {
                'front': 'E=mc2',
                'back': 'Énergie et masse',
                'reps': 4,
                'interval': 10,
                'ease': 2.5,
              }
            ],
          }
        ]
      };

      final result = await provider.importFullBackup(jsonEncode(backupData));
      expect(result['decksAdded'], 1);
      expect(result['cardsAdded'], 2);
      expect(result['cardsUpdated'], 1);

      final chimDeck = provider.decks.firstWhere((d) => d.name == 'Chimie');
      expect(chimDeck.allCards.length, 2); // Pas de doublon H2O !
      final h2oCard = chimDeck.allCards.firstWhere((c) => c.front == 'H2O');
      expect(h2oCard.reps, 5); // FSRS mis à jour par merge !

      final physDeck = provider.decks.firstWhere((d) => d.name == 'Physique');
      expect(physDeck.allCards.length, 1);
      expect(physDeck.mode, FsrsMode.longTermDays);
    });
  });

  group('Deck Rename & Settings', () {
    test('renameDeck renomme avec succès et refuse les doublons', () async {
      final storage = StorageService();
      final provider = DeckProvider(storage);
      await provider.loadDecks();

      final deck1 = await provider.createDeck('Maths');
      final deck2 = await provider.createDeck('Histoire');

      final success = await provider.renameDeck(deck1, 'Mathématiques');
      expect(success, isTrue);
      expect(deck1.name, 'Mathématiques');

      // Tenter de renommer deck2 en 'Mathématiques' (doublon)
      final duplicateFail = await provider.renameDeck(deck2, 'mathématiques');
      expect(duplicateFail, isFalse);
      expect(deck2.name, 'Histoire');
    });

    test('SettingsProvider gère qcmGoodAnswerDuration avec clamping', () {
      final settings = SettingsProvider();
      expect(settings.qcmGoodAnswerDuration, 1.0); // défaut

      settings.setQcmGoodAnswerDuration(2.5);
      expect(settings.qcmGoodAnswerDuration, 2.5);

      // Clamping test
      settings.setQcmGoodAnswerDuration(10.0);
      expect(settings.qcmGoodAnswerDuration, 5.0);

      settings.setQcmGoodAnswerDuration(0.1);
      expect(settings.qcmGoodAnswerDuration, 0.5);
    });
  });
}
