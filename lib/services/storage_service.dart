import 'dart:convert';
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
  String? _storageDirectoryPath;
  bool didAutoRestoreFromMirror = false;

  Isar? get isar => _isar;
  bool get hasIsar => _isar != null && !kIsWeb;

  StorageService([Isar? isarInstance]) {
    if (isarInstance != null) {
      _isar = isarInstance;
    }
  }

  /// Initialise l'instance Isar avec les schémas, sécurité de verrou et miroir JSON
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
    _storageDirectoryPath = path;

    try {
      _isar = await Isar.open(
        [DeckSchema, FlashcardSchema],
        directory: path,
        name: 'default',
      );
    } catch (e) {
      debugPrint('Isar.open primary error: $e. Tentative de réouverture propre sans suppression de base...');
      try {
        // Nettoyage UNIQUEMENT du fichier de lock si un arrêt brusque a eu lieu, JAMAIS du fichier de données .isar
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

    // Auto-restauration depuis le miroir JSON si la base est vide
    await _checkAndAutoRestoreMirror(path);
  }

  /// Vérifie si la base est vide et auto-restaure depuis le miroir JSON permanent
  Future<void> _checkAndAutoRestoreMirror(String path) async {
    try {
      final mirrorFile = File('$path/vault_backup.json');
      if (await mirrorFile.exists()) {
        final jsonStr = await mirrorFile.readAsString();
        if (jsonStr.trim().isNotEmpty) {
          final existing = await getAllDecks();
          if (existing.isEmpty) {
            final stats = await importFullBackupJson(jsonStr);
            if ((stats['decksAdded'] ?? 0) > 0 || (stats['cardsAdded'] ?? 0) > 0) {
              didAutoRestoreFromMirror = true;
              debugPrint('Auto-restauration réussie depuis le miroir JSON: $stats');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification du miroir JSON: $e');
    }
  }

  /// Écrit une sauvegarde miroir atomique sur le disque local
  Future<void> _writeMirrorBackup() async {
    if (kIsWeb) return;
    try {
      final path = _storageDirectoryPath;
      if (path == null) return;

      final jsonStr = await exportFullBackupJson();
      final tmpFile = File('$path/vault_backup.json.tmp');
      await tmpFile.writeAsString(jsonStr, flush: true);
      final targetFile = File('$path/vault_backup.json');
      await tmpFile.rename(targetFile.path);
    } catch (e) {
      debugPrint('Erreur écriture miroir JSON: $e');
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
      _writeMirrorBackup();
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

    _writeMirrorBackup();
    return newDeck;
  }

  /// Renomme un paquet avec contrôle d'unicité
  Future<bool> renameDeck(Deck deck, String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return false;
    if (clean == deck.name) return true;

    if (!hasIsar) {
      final conflict = _webDecks.any((d) => d.id != deck.id && d.name.toLowerCase() == clean.toLowerCase());
      if (conflict) return false;
      final target = _webDecks.where((d) => d.id == deck.id).firstOrNull ?? deck;
      target.name = clean;
      deck.name = clean;
      _writeMirrorBackup();
      return true;
    }

    final conflict = await _isar!.decks.filter().nameEqualTo(clean, caseSensitive: false).findFirst();
    if (conflict != null && conflict.id != deck.id) return false;

    await _isar!.writeTxn(() async {
      final actual = await _isar!.decks.get(deck.id) ?? deck;
      actual.name = clean;
      deck.name = clean;
      await _isar!.decks.put(actual);
    });
    _writeMirrorBackup();
    return true;
  }

  /// Met à jour un paquet
  Future<void> updateDeck(Deck deck) async {
    if (!hasIsar) {
      final idx = _webDecks.indexWhere((d) => d.id == deck.id);
      if (idx != -1) {
        _webDecks[idx] = deck;
      }
      _writeMirrorBackup();
      return;
    }

    await _isar!.writeTxn(() async {
      final actual = await _isar!.decks.get(deck.id) ?? deck;
      actual.name = deck.name;
      actual.mode = deck.mode;
      actual.isActive = deck.isActive;
      await _isar!.decks.put(actual);
    });
    _writeMirrorBackup();
  }

  /// Supprime un paquet et toutes ses cartes associées
  Future<void> deleteDeck(Id deckId) async {
    if (!hasIsar) {
      _webDecks.removeWhere((d) => d.id == deckId);
      _writeMirrorBackup();
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
    _writeMirrorBackup();
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
    _writeMirrorBackup();
  }

  /// Sauvegarde ou met à jour une seule carte
  Future<void> saveCard(Flashcard card) async {
    if (!hasIsar) {
      if (card.deck.value != null) {
        card.deck.value!.webCards.removeWhere((c) => c.id == card.id);
        card.deck.value!.webCards.add(card);
      }
      _writeMirrorBackup();
      return;
    }

    await _isar!.writeTxn(() async {
      await _isar!.flashcards.put(card);
      await card.deck.save();
    });
    _writeMirrorBackup();
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
      _writeMirrorBackup();
      return;
    }

    await _isar!.writeTxn(() async {
      await _isar!.flashcards.putAll(cards);
      for (var card in cards) {
        await card.deck.save();
      }
    });
    _writeMirrorBackup();
  }

  /// Supprime une carte
  Future<void> deleteCard(Id cardId) async {
    if (!hasIsar) {
      for (var d in _webDecks) {
        d.webCards.removeWhere((c) => c.id == cardId);
      }
      _writeMirrorBackup();
      return;
    }

    await _isar!.writeTxn(() async {
      await _isar!.flashcards.delete(cardId);
    });
    _writeMirrorBackup();
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

  /// Exporte l'intégralité de la base de données (paquets, cartes avec toutes les métriques FSRS et réglages)
  Future<String> exportFullBackupJson({Map<String, dynamic>? extraSettings}) async {
    final allDecks = await getAllDecks();
    final List<Map<String, dynamic>> decksData = [];

    for (final deck in allDecks) {
      final cards = await getCardsForDeck(deck.id);
      decksData.add({
        'name': deck.name,
        'mode': deck.mode == FsrsMode.intensiveMinutes ? 'intensiveMinutes' : 'longTermDays',
        'isActive': deck.isActive,
        'createdAt': deck.createdAt.toIso8601String(),
        'cards': cards.map((c) => {
          'front': c.front,
          'back': c.back,
          'reps': c.reps,
          'interval': c.interval,
          'ease': c.ease,
          'dueDate': c.dueDate.toIso8601String(),
          'lastReviewed': c.lastReviewed?.toIso8601String(),
        }).toList(),
      });
    }

    final Map<String, dynamic> root = {
      'app': 'Kawaii Flashcards',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      if (extraSettings != null) 'settings': extraSettings,
      'decks': decksData,
    };

    return const JsonEncoder.withIndent('  ').convert(root);
  }

  /// Importe une sauvegarde JSON avec Fusion Intelligente Systématique
  /// Retourne un résumé : {'decksAdded': count, 'cardsAdded': count, 'cardsUpdated': count}
  Future<Map<String, int>> importFullBackupJson(String jsonStr) async {
    int decksAdded = 0;
    int cardsAdded = 0;
    int cardsUpdated = 0;

    final dynamic parsed = jsonDecode(jsonStr);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Le fichier de sauvegarde n\'est pas un objet JSON valide.');
    }

    final rawDecks = parsed['decks'];
    if (rawDecks is! List) {
      return {'decksAdded': 0, 'cardsAdded': 0, 'cardsUpdated': 0};
    }

    for (final rawDeck in rawDecks) {
      if (rawDeck is! Map) continue;
      final deckMap = Map<String, dynamic>.from(rawDeck);
      final deckName = (deckMap['name'] as String?)?.trim();
      if (deckName == null || deckName.isEmpty) continue;

      final modeStr = deckMap['mode'] as String?;
      final mode = modeStr == 'longTermDays' ? FsrsMode.longTermDays : FsrsMode.intensiveMinutes;
      final isActive = deckMap['isActive'] as bool? ?? true;
      final createdAtStr = deckMap['createdAt'] as String?;
      final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

      // Chercher ou créer le paquet
      final existingDecks = await getAllDecks();
      Deck? targetDeck = existingDecks.where((d) => d.name.toLowerCase() == deckName.toLowerCase()).firstOrNull;

      if (targetDeck == null) {
        targetDeck = await createDeck(deckName, mode: mode);
        targetDeck.isActive = isActive;
        if (createdAt != null) targetDeck.createdAt = createdAt;
        await updateDeck(targetDeck);
        decksAdded++;
      }

      // Parcourir les cartes du paquet
      final rawCards = deckMap['cards'];
      if (rawCards is List && rawCards.isNotEmpty) {
        final existingCards = await getCardsForDeck(targetDeck.id);
        final List<Flashcard> cardsToAdd = [];
        final List<Flashcard> cardsToSave = [];

        for (final rawCard in rawCards) {
          if (rawCard is! Map) continue;
          final cardMap = Map<String, dynamic>.from(rawCard);
          final front = (cardMap['front'] as String?)?.trim();
          final back = (cardMap['back'] as String?)?.trim();
          if (front == null || front.isEmpty || back == null || back.isEmpty) continue;

          final reps = cardMap['reps'] as int? ?? 0;
          final interval = (cardMap['interval'] as num?)?.toDouble() ?? 0.0;
          final ease = (cardMap['ease'] as num?)?.toDouble() ?? 2.5;
          final dueDateStr = cardMap['dueDate'] as String?;
          final dueDate = dueDateStr != null ? (DateTime.tryParse(dueDateStr) ?? DateTime.now()) : DateTime.now();
          final lastReviewedStr = cardMap['lastReviewed'] as String?;
          final lastReviewed = lastReviewedStr != null ? DateTime.tryParse(lastReviewedStr) : null;

          final existingCard = existingCards.where((c) => c.front.trim() == front).firstOrNull;
          if (existingCard == null) {
            final newCard = Flashcard()
              ..front = front
              ..back = back
              ..reps = reps
              ..interval = interval
              ..ease = ease
              ..dueDate = dueDate
              ..lastReviewed = lastReviewed;
            cardsToAdd.add(newCard);
            cardsAdded++;
          } else {
            // Mise à jour si la carte importée a plus de révisions ou une date de révision plus récente
            bool shouldUpdate = false;
            if (reps > existingCard.reps) {
              shouldUpdate = true;
            } else if (lastReviewed != null && (existingCard.lastReviewed == null || lastReviewed.isAfter(existingCard.lastReviewed!))) {
              shouldUpdate = true;
            }

            if (shouldUpdate) {
              existingCard.back = back;
              existingCard.reps = reps;
              existingCard.interval = interval;
              existingCard.ease = ease;
              existingCard.dueDate = dueDate;
              existingCard.lastReviewed = lastReviewed;
              cardsToSave.add(existingCard);
              cardsUpdated++;
            }
          }
        }

        if (cardsToAdd.isNotEmpty) {
          await addCardsToDeck(cardsToAdd, targetDeck);
        }
        if (cardsToSave.isNotEmpty) {
          await saveCards(cardsToSave);
        }
      }
    }

    _writeMirrorBackup();
    return {
      'decksAdded': decksAdded,
      'cardsAdded': cardsAdded,
      'cardsUpdated': cardsUpdated,
    };
  }
}
