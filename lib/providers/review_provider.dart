import 'package:flutter/foundation.dart';
import '../models/flashcard.dart';
import '../services/fsrs_service.dart';
import '../services/storage_service.dart';

class ReviewProvider with ChangeNotifier {
  List<Flashcard> _reviewQueue = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isRandomOrder = false;

  List<Flashcard> get reviewQueue => _reviewQueue;
  int get currentIndex => _currentIndex;
  bool get isFlipped => _isFlipped;
  bool get isRandomOrder => _isRandomOrder;

  Flashcard? get currentCard =>
      (_currentIndex >= 0 && _currentIndex < _reviewQueue.length)
          ? _reviewQueue[_currentIndex]
          : null;

  bool get isSessionFinished => _currentIndex >= _reviewQueue.length;
  int get totalInSession => _reviewQueue.length;
  int get progressNumber => _currentIndex + 1;

  /// Initialise la file d'attente pour la session
  void initSession({
    required List<Flashcard> cards,
    bool isRandomOrder = false,
  }) {
    _isRandomOrder = isRandomOrder;
    _currentIndex = 0;
    _isFlipped = false;

    final copy = List<Flashcard>.from(cards);
    if (isRandomOrder) {
      copy.shuffle();
      _reviewQueue = copy;
    } else {
      // Tri par urgence FSRS : dueDate la plus ancienne en premier
      copy.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      _reviewQueue = copy;
    }

    notifyListeners();
  }

  /// Bascule l'ordre aléatoire en direct durant la session
  /// Conserve la carte courante affichée et mélange/réordonne la suite de la file
  void toggleRandomOrder() {
    _isRandomOrder = !_isRandomOrder;
    if (_reviewQueue.isNotEmpty && _currentIndex < _reviewQueue.length) {
      final current = _reviewQueue[_currentIndex];
      final remaining = _reviewQueue.sublist(_currentIndex + 1);
      if (_isRandomOrder) {
        remaining.shuffle();
      } else {
        remaining.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      }
      _reviewQueue = [
        ..._reviewQueue.sublist(0, _currentIndex),
        current,
        ...remaining,
      ];
    }
    notifyListeners();
  }

  /// Retourne la carte
  void flipCard() {
    if (_isFlipped) return;
    _isFlipped = true;
    notifyListeners();
  }

  /// Note la carte courante et applique l'algorithme FSRS
  FsrsResult? rateCurrentCard({
    required int rating,
    required bool isIntensiveMinutes,
    double desiredRetention = 0.90,
    StorageService? storage,
  }) {
    final card = currentCard;
    if (card == null) return null;

    final result = FsrsService.calculateNextReview(
      reps: card.reps,
      interval: card.interval,
      ease: card.ease,
      rating: rating,
      isIntensiveMinutes: isIntensiveMinutes,
      desiredRetention: desiredRetention,
    );

    // Mettre à jour l'entité
    card.reps = result.reps;
    card.interval = result.interval;
    card.ease = result.ease;
    card.dueDate = result.dueDate;
    card.lastReviewed = DateTime.now();

    // Persister si storage disponible
    storage?.saveCard(card);

    // Si rating 1 (Again), réinsérer la carte à la fin de la file de la session en cours
    if (rating == 1) {
      _reviewQueue.add(card);
    }

    // Passer à la carte suivante
    _currentIndex++;
    _isFlipped = false;

    notifyListeners();
    return result;
  }

  /// Génère 4 choix uniques pour le Mode Colles (QCM)
  List<String> generateQcmChoices({
    required Flashcard currentCard,
    List<Flashcard>? allPoolCards,
  }) {
    final correctAnswer = currentCard.back.trim();
    final Set<String> distractors = {};

    // 1. Chercher d'abord dans la file de révision
    for (var card in _reviewQueue) {
      final answer = card.back.trim();
      if (answer != correctAnswer && answer.isNotEmpty) {
        distractors.add(answer);
      }
      if (distractors.length >= 3) break;
    }

    // 2. Si moins de 3 distracteurs, piocher dans le pool global fourni (autres paquets)
    if (distractors.length < 3 && allPoolCards != null) {
      final shuffledPool = List<Flashcard>.from(allPoolCards)..shuffle();
      for (var card in shuffledPool) {
        final answer = card.back.trim();
        if (answer != correctAnswer && answer.isNotEmpty) {
          distractors.add(answer);
        }
        if (distractors.length >= 3) break;
      }
    }

    // 3. Assembler les choix et mélanger
    final choices = <String>[correctAnswer, ...distractors.take(3)];
    choices.shuffle();
    return choices;
  }

  /// Gère la réponse au QCM
  bool handleQcmAnswer({
    required String selectedAnswer,
    required bool isIntensiveMinutes,
    StorageService? storage,
  }) {
    final card = currentCard;
    if (card == null) return false;

    final isCorrect = selectedAnswer.trim() == card.back.trim();
    final rating = isCorrect ? 4 : 1;

    rateCurrentCard(
      rating: rating,
      isIntensiveMinutes: isIntensiveMinutes,
      storage: storage,
    );

    return isCorrect;
  }
}
