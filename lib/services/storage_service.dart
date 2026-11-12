import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';

class StorageService {
  Isar? _isar;
  final List<Deck> _webDecks = [];
  int _webIdCounter = 1;

  Isar? get isar => _isar;
  bool get hasIsar => _isar != null && !kIsWeb;

  StorageService([Isar? isarInstance]) {
    if (isarInstance != null) {
      _isar = isarInstance;
    }
  }

  /// Initialise l'instance Isar avec les schémas et récupération automatique en cas d'erreur
  Future<void> init({String? customPath}) async {
    if (kIsWeb) {
      return;
    }

    if (Isar.instanceNames.contains('default')) {
      _isar = Isar.getInstance('default');
      return;
    }

    String path;
    if (customPath != null) {
      path = customPath;
    } else {
      try {
        final dir = await getApplicationDocumentsDirectory();
        path = dir.path;
      } catch (e) {
        debugPrint('getApplicationDocumentsDirectory error: $e');
        return;
      }
    }

    try {
      _isar = await Isar.open(
        [DeckSchema, FlashcardSchema],
        directory: path,
        name: 'default',
      );
    } catch (e) {
      debugPrint('Isar.open primary error: $e. Tentative de réinitialisation propre...');
      try {
        // En cas d'incompatibilité de schéma lors d'une mise à jour (v1.0 -> v1.1)
        final dbFile = File('$path/default.isar');
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
        final lockFile = File('$path/default.isar.lock');
        if (await lockFile.exists()) {
          await lockFile.delete();
        }
        _isar = await Isar.open(
          [DeckSchema, FlashcardSchema],
          directory: path,
          name: 'default',
        );
      } catch (e2) {
        debugPrint('Isar recovery error: $e2. Bascule en mode mémoire de secours.');
      }
    }
  }

  /// Récupère tous les paquets
  Future<List<Deck>> getAllDecks() async {
    if (!hasIsar) {
      return List.unmodifiable(_webDecks);
    }
    try {
      final decks = await _isar!.decks.where().findAll();
      for (var deck in decks) {
        await deck.cards.load();
      }
      return decks;
    } catch (e) {
      debugPrint('getAllDecks error: $e');
      return List.unmodifiable(_webDecks);
    }
  }

  /// Crée un nouveau paquet
  Future<Deck> createDeck(String name, {FsrsMode mode = FsrsMode.intensiveMinutes}) async {
    if (!hasIsar) {
      final existing = _webDecks.where((d) => d.name == name.trim()).firstOrNull;
      if (existing != null) {
        return existing;
      }
      final newDeck = Deck()
        ..id = _webIdCounter++
        ..name = name.trim()
        ..mode = mode
        ..createdAt = DateTime.now();
      _webDecks.add(newDeck);
      return newDeck;
    }

    final existing = await _isar!.decks.filter().nameEqualTo(name.trim()).findFirst();
    if (existing != null) {
      return existing;
    }

    final newDeck = Deck()
      ..name = name.trim()
      ..mode = mode
      ..createdAt = DateTime.now();

    await _isar!.writeTxn(() async {
      await _isar!.decks.put(newDeck);
    });

    return newDeck;
  }

  /// Met à jour un paquet
  Future<void> updateDeck(Deck deck) async {
    if (!hasIsar) {
      final idx = _webDecks.indexWhere((d) => d.id == deck.id);
      if (idx != -1) {
        _webDecks[idx] = deck;
      }
      return;
    }

    await _isar!.writeTxn(() async {
      await _isar!.decks.put(deck);
    });
  }

  /// Supprime un paquet et toutes ses cartes associées
  Future<void> deleteDeck(Id deckId) async {
    if (!hasIsar) {
      _webDecks.removeWhere((d) => d.id == deckId);
      return;
    }

    final deck = await _isar!.decks.get(deckId);
    if (deck == null) return;

    await deck.cards.load();
    final cardIds = deck.cards.map((c) => c.id).toList();

    await _isar!.writeTxn(() async {
      await _isar!.flashcards.deleteAll(cardIds);
      await _isar!.decks.delete(deckId);
    });
  }

  /// Récupère toutes les cartes d'un paquet
  Future<List<Flashcard>> getCardsForDeck(Id deckId) async {
    if (!hasIsar) {
      final deck = _webDecks.where((d) => d.id == deckId).firstOrNull;
      return deck?.webCards.toList() ?? [];
    }

    final deck = await _isar!.decks.get(deckId);
    if (deck == null) return [];
    await deck.cards.load();
    return deck.cards.toList();
  }

  /// Ajoute une liste de cartes dans un paquet
  Future<void> addCardsToDeck(List<Flashcard> cards, Deck deck) async {
    if (!hasIsar) {
      final targetDeck = _webDecks.where((d) => d.id == deck.id).firstOrNull ?? deck;
      for (var card in cards) {
        if (card.id == Isar.autoIncrement || card.id == 0) {
          card.id = _webIdCounter++;
        }
        card.deck.value = targetDeck;
        if (!targetDeck.webCards.contains(card)) {
          targetDeck.webCards.add(card);
        }
        if (deck != targetDeck && !deck.webCards.contains(card)) {
          deck.webCards.add(card);
        }
      }
      return;
    }

    final targetDeck = await _isar!.decks.get(deck.id) ?? deck;
    await _isar!.writeTxn(() async {
      await _isar!.flashcards.putAll(cards);
      for (var card in cards) {
        card.deck.value = targetDeck;
        await card.deck.save();
      }
    });

    await targetDeck.cards.load();
    if (deck != targetDeck) {
      await deck.cards.load();
    }
  }

  /// Sauvegarde ou met à jour une seule carte
  Future<void> saveCard(Flashcard card) async {
    if (!hasIsar) {
      if (card.deck.value != null) {
        card.deck.value!.webCards.removeWhere((c) => c.id == card.id);
        card.deck.value!.webCards.add(card);
      }
      return;
    }

    await _isar!.writeTxn(() async {
      await _isar!.flashcards.put(card);
      await card.deck.save();
    });
  }

  /// Sauvegarde ou met à jour plusieurs cartes
  Future<void> saveCards(List<Flashcard> cards) async {
    if (!hasIsar) {
      for (final card in cards) {
        if (card.deck.value != null) {
          card.deck.value!.webCards.removeWhere((c) => c.id == card.id);
          card.deck.value!.webCards.add(card);
        }
      }
      return;
    }

    await _isar!.writeTxn(() async {
      await _isar!.flashcards.putAll(cards);
      for (var card in cards) {
        await card.deck.save();
      }
    });
  }

  /// Supprime une carte
  Future<void> deleteCard(Id cardId) async {
    if (!hasIsar) {
      for (var d in _webDecks) {
        d.webCards.removeWhere((c) => c.id == cardId);
      }
      return;
    }

    await _isar!.writeTxn(() async {
      await _isar!.flashcards.delete(cardId);
    });
  }

  /// Récupère toutes les cartes de la base (pour distracteurs QCM fallback)
  Future<List<Flashcard>> getAllCards() async {
    if (!hasIsar) {
      return _webDecks.expand((d) => d.webCards).toList();
    }

    return await _isar!.flashcards.where().findAll();
  }

  /// Récupère toutes les cartes dues pour une liste d'identifiants de paquets
  Future<List<Flashcard>> getDueCardsForDecks(List<Id> deckIds, {DateTime? now}) async {
    final reference = now ?? DateTime.now();

    if (!hasIsar) {
      final allDue = <Flashcard>[];
      for (var deckId in deckIds) {
        final deck = _webDecks.where((d) => d.id == deckId).firstOrNull;
        if (deck == null) continue;
        allDue.addAll(deck.webCards.where((c) => c.dueDate.isBefore(reference) || c.dueDate.isAtSameMomentAs(reference)));
      }
      return allDue;
    }

    final allDue = <Flashcard>[];

    for (var deckId in deckIds) {
      final deck = await _isar!.decks.get(deckId);
      if (deck == null) continue;
      await deck.cards.load();

      final dueCards = deck.cards.where((c) => c.dueDate.isBefore(reference) || c.dueDate.isAtSameMomentAs(reference));
      allDue.addAll(dueCards);
    }

    return allDue;
  }
}
