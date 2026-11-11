import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../services/csv_service.dart';
import '../services/fsrs_service.dart';
import '../services/storage_service.dart';

class DeckProvider with ChangeNotifier {
  final StorageService _storage;

  List<Deck> _decks = [];
  final Set<Id> _selectedDeckIds = {};
  bool _isLoading = false;

  DeckProvider(this._storage);

  List<Deck> get decks => _decks;
  List<Deck> get activeDecks => _decks.where((d) => d.isActive).toList();
  Set<Id> get selectedDeckIds => _selectedDeckIds;
  bool get isLoading => _isLoading;

  /// Charge tous les paquets et leurs cartes
  Future<void> loadDecks() async {
    _isLoading = true;
    notifyListeners();

    _decks = await _storage.getAllDecks();

    // Par défaut, si aucun paquet n'est sélectionné, sélectionner tous les paquets actifs
    if (_selectedDeckIds.isEmpty && _decks.isNotEmpty) {
      _selectedDeckIds.addAll(_decks.where((d) => d.isActive).map((d) => d.id));
    } else {
      // Nettoyer les paquets inactifs ou supprimés de la sélection
      final activeIds = _decks.where((d) => d.isActive).map((d) => d.id).toSet();
      _selectedDeckIds.retainAll(activeIds);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Bascule la sélection d'un paquet pour la révision groupée
  void toggleDeckSelection(Id deckId) {
    if (_selectedDeckIds.contains(deckId)) {
      _selectedDeckIds.remove(deckId);
    } else {
      _selectedDeckIds.add(deckId);
    }
    notifyListeners();
  }

  /// Sélectionne tous les paquets actifs
  void selectAllDecks() {
    _selectedDeckIds.clear();
    _selectedDeckIds.addAll(_decks.where((d) => d.isActive).map((d) => d.id));
    notifyListeners();
  }

  /// Désélectionne tous les paquets
  void clearSelection() {
    _selectedDeckIds.clear();
    notifyListeners();
  }

  /// Active ou désactive un paquet (inactif = non compté dans total, rappels FSRS et accueil)
  Future<void> toggleDeckActive(Deck deck) async {
    deck.isActive = !deck.isActive;
    if (!deck.isActive) {
      _selectedDeckIds.remove(deck.id);
    }
    await _storage.updateDeck(deck);
    await loadDecks();
  }

  /// Bascule rapidement le mode d'un paquet (Colles <-> Long Terme) avec transposition FSRS intelligente
  Future<void> switchDeckMode(Deck deck, FsrsMode newMode) async {
    if (deck.mode == newMode) return;
    final toLongTerm = newMode == FsrsMode.longTermDays;

    await deck.cards.load();
    final cardsList = deck.allCards.toList();
    for (final card in cardsList) {
      FsrsService.transposeCardMode(
        card: card,
        toLongTermDays: toLongTerm,
      );
    }

    deck.mode = newMode;
    await _storage.updateDeck(deck);
    if (cardsList.isNotEmpty) {
      await _storage.saveCards(cardsList);
    }
    await loadDecks();
  }

  /// Crée un nouveau paquet
  Future<Deck> createDeck(String name, {FsrsMode mode = FsrsMode.intensiveMinutes}) async {
    final deck = await _storage.createDeck(name, mode: mode);
    await loadDecks();
    _selectedDeckIds.add(deck.id);
    notifyListeners();
    return deck;
  }

  /// Met à jour un paquet
  Future<void> updateDeck(Deck deck) async {
    await _storage.updateDeck(deck);
    await loadDecks();
  }

  /// Supprime un paquet
  Future<void> deleteDeck(Id deckId) async {
    await _storage.deleteDeck(deckId);
    _selectedDeckIds.remove(deckId);
    await loadDecks();
  }

  /// Ajoute une carte sur une seule ligne à un paquet
  Future<Flashcard> addCard({
    required Deck deck,
    required String front,
    required String back,
  }) async {
    // Sanitiser pour respecter la règle "une seule ligne"
    final cleanFront = front.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final cleanBack = back.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

    final card = Flashcard()
      ..front = cleanFront
      ..back = cleanBack
      ..reps = 0
      ..interval = 0.0
      ..ease = 2.5
      ..dueDate = DateTime.now();

    await _storage.addCardsToDeck([card], deck);
    await loadDecks();
    return card;
  }

  /// Supprime une carte
  Future<void> deleteCard(Id cardId) async {
    await _storage.deleteCard(cardId);
    await loadDecks();
  }

  /// Met à jour une carte
  Future<void> updateCard(Flashcard card) async {
    card.front = card.front.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    card.back = card.back.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    await _storage.saveCard(card);
    await loadDecks();
  }

  /// Importe des cartes CSV dans un paquet donné
  Future<int> importCsv({
    required Deck deck,
    required String csvContent,
    String delimiter = ',',
    String? lineSeparator,
  }) async {
    final items = CsvService.parseCsv(
      csvContent,
      delimiter: delimiter,
      lineSeparator: lineSeparator,
    );

    if (items.isEmpty) return 0;

    final cards = items.map((item) {
      return Flashcard()
        ..front = item.front
        ..back = item.back
        ..reps = 0
        ..interval = 0.0
        ..ease = 2.5
        ..dueDate = DateTime.now();
    }).toList();

    await _storage.addCardsToDeck(cards, deck);
    await loadDecks();
    return cards.length;
  }

  /// Exporte un paquet en CSV avec séparateurs configurables
  Future<String> exportDeckCsv(
    Deck deck, {
    String delimiter = ',',
    String lineEnding = '\n',
  }) async {
    await deck.cards.load();
    final items = deck.cards.map((c) => CsvCardItem(front: c.front, back: c.back)).toList();
    return CsvService.exportCsv(items, delimiter: delimiter, lineEnding: lineEnding);
  }

  /// Total de cartes tous paquets ACTIFS confondus
  int get totalCardsCount {
    int total = 0;
    for (var d in _decks) {
      if (d.isActive) {
        total += d.allCards.length;
      }
    }
    return total;
  }

  /// Total de cartes dues tous paquets ACTIFS confondus
  int get totalDueCardsCount {
    final now = DateTime.now();
    int due = 0;
    for (var d in _decks) {
      if (d.isActive) {
        due += d.allCards.where((c) => c.dueDate.isBefore(now) || c.dueDate.isAtSameMomentAs(now)).length;
      }
    }
    return due;
  }

  /// Nombre de cartes dues pour la sélection active
  int get selectedDueCardsCount {
    final now = DateTime.now();
    int due = 0;
    for (var d in _decks) {
      if (_selectedDeckIds.contains(d.id)) {
        due += d.allCards.where((c) => c.dueDate.isBefore(now) || c.dueDate.isAtSameMomentAs(now)).length;
      }
    }
    return due;
  }

  /// Nombre de cartes dues pour un paquet spécifique
  int getDueCardsCountForDeck(Deck deck) {
    final now = DateTime.now();
    return deck.allCards.where((c) => c.dueDate.isBefore(now) || c.dueDate.isAtSameMomentAs(now)).length;
  }

  /// Récupère toutes les cartes dues des paquets actuellement sélectionnés
  List<Flashcard> getDueCardsForSelected() {
    final now = DateTime.now();
    final List<Flashcard> dueCards = [];
    for (var d in _decks) {
      if (_selectedDeckIds.contains(d.id)) {
        dueCards.addAll(d.allCards.where((c) => c.dueDate.isBefore(now) || c.dueDate.isAtSameMomentAs(now)));
      }
    }
    return dueCards;
  }

  /// Récupère toutes les cartes des paquets sélectionnés (pour session d'entraînement hors FSRS ou révision)
  List<Flashcard> getAllCardsForSelected() {
    final List<Flashcard> list = [];
    for (var d in _decks) {
      if (_selectedDeckIds.contains(d.id)) {
        list.addAll(d.allCards);
      }
    }
    return list;
  }

  /// Récupère toutes les cartes de la base pour le fallback des distracteurs QCM
  Future<List<Flashcard>> getAllCardsPool() async {
    return await _storage.getAllCards();
  }

  /// Récupère toutes les cartes appartenant à des paquets actifs (pour les notifications prédictives)
  List<Flashcard> getActiveCardsPool() {
    final List<Flashcard> cards = [];
    for (var d in _decks) {
      if (d.isActive) {
        cards.addAll(d.allCards);
      }
    }
    return cards;
  }

  /// Détermine si la sélection courante est en mode Colles (minutes)
  /// Si au moins un paquet sélectionné est en mode Colles, on applique le mode minutes
  bool get isSelectedModeIntensive {
    for (var d in _decks) {
      if (_selectedDeckIds.contains(d.id) && d.mode == FsrsMode.intensiveMinutes) {
        return true;
      }
    }
    return false;
  }
}
