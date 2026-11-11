import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';

class StorageService {
  late Isar _isar;

  Isar get isar => _isar;

  StorageService([Isar? isarInstance]) {
    if (isarInstance != null) {
      _isar = isarInstance;
    }
  }

  /// Initialise l'instance Isar avec les schémas
  Future<void> init({String? customPath}) async {
    if (Isar.instanceNames.contains('default')) {
      _isar = Isar.getInstance('default')!;
      return;
    }

    String path;
    if (customPath != null) {
      path = customPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = dir.path;
    }

    _isar = await Isar.open(
      [DeckSchema, FlashcardSchema],
      directory: path,
      name: 'default',
    );
  }

  /// Récupère tous les paquets
  Future<List<Deck>> getAllDecks() async {
    final decks = await _isar.decks.where().findAll();
    for (var deck in decks) {
      await deck.cards.load();
    }
    return decks;
  }

  /// Crée un nouveau paquet
  Future<Deck> createDeck(String name, {FsrsMode mode = FsrsMode.intensiveMinutes}) async {
    final existing = await _isar.decks.filter().nameEqualTo(name.trim()).findFirst();
    if (existing != null) {
      return existing;
    }

    final newDeck = Deck()
      ..name = name.trim()
      ..mode = mode
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.decks.put(newDeck);
    });

    return newDeck;
  }

  /// Met à jour un paquet
  Future<void> updateDeck(Deck deck) async {
    await _isar.writeTxn(() async {
      await _isar.decks.put(deck);
    });
  }

  /// Supprime un paquet et toutes ses cartes associées
  Future<void> deleteDeck(Id deckId) async {
    final deck = await _isar.decks.get(deckId);
    if (deck == null) return;

    await deck.cards.load();
    final cardIds = deck.cards.map((c) => c.id).toList();

    await _isar.writeTxn(() async {
      await _isar.flashcards.deleteAll(cardIds);
      await _isar.decks.delete(deckId);
    });
  }

  /// Récupère toutes les cartes d'un paquet
  Future<List<Flashcard>> getCardsForDeck(Id deckId) async {
    final deck = await _isar.decks.get(deckId);
    if (deck == null) return [];
    await deck.cards.load();
    return deck.cards.toList();
  }

  /// Ajoute une liste de cartes dans un paquet
  Future<void> addCardsToDeck(List<Flashcard> cards, Deck deck) async {
    await _isar.writeTxn(() async {
      for (var card in cards) {
        card.deck.value = deck;
        await _isar.flashcards.put(card);
        await card.deck.save();
      }
      await deck.cards.save();
    });
  }

  /// Sauvegarde ou met à jour une seule carte
  Future<void> saveCard(Flashcard card) async {
    await _isar.writeTxn(() async {
      await _isar.flashcards.put(card);
      await card.deck.save();
    });
  }

  /// Supprime une carte
  Future<void> deleteCard(Id cardId) async {
    await _isar.writeTxn(() async {
      await _isar.flashcards.delete(cardId);
    });
  }

  /// Récupère toutes les cartes de la base (pour distracteurs QCM fallback)
  Future<List<Flashcard>> getAllCards() async {
    return await _isar.flashcards.where().findAll();
  }

  /// Récupère toutes les cartes dues pour une liste d'identifiants de paquets
  Future<List<Flashcard>> getDueCardsForDecks(List<Id> deckIds, {DateTime? now}) async {
    final reference = now ?? DateTime.now();
    final allDue = <Flashcard>[];

    for (var deckId in deckIds) {
      final deck = await _isar.decks.get(deckId);
      if (deck == null) continue;
      await deck.cards.load();

      final dueCards = deck.cards.where((c) => c.dueDate.isBefore(reference) || c.dueDate.isAtSameMomentAs(reference));
      allDue.addAll(dueCards);
    }

    return allDue;
  }
}
