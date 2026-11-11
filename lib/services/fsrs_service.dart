import 'dart:math';
import '../models/flashcard.dart';

/// Résultat du calcul de prochaine révision FSRS
class FsrsResult {
  final int reps;
  final double interval;
  final double ease;
  final DateTime dueDate;

  const FsrsResult({
    required this.reps,
    required this.interval,
    required this.ease,
    required this.dueDate,
  });
}

/// Service de calcul de répétition espacée FSRS / SM-2
class FsrsService {
  /// Calcule la prochaine révision pour une carte donnée
  /// Rating:
  /// 1 = Again (À revoir)
  /// 2 = Hard (Difficile)
  /// 3 = Good (Bien)
  /// 4 = Easy (Facile)
  static FsrsResult calculateNextReview({
    required int reps,
    required double interval,
    required double ease,
    required int rating,
    required bool isIntensiveMinutes,
    double desiredRetention = 0.90,
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();
    int newReps = reps + 1;
    double newEase = ease;
    double newInterval = interval;

    // Multiplicateur FSRS basé sur le taux de rétention souhaité (baseline 90%)
    final clampedR = desiredRetention.clamp(0.70, 0.98);
    final double retentionFactor = log(clampedR) / log(0.90);

    if (isIntensiveMinutes) {
      // --- MODE COLLES (Minutes) ---
      if (rating == 1) {
        newInterval = 1.0;
        newEase = max(1.3, ease - 0.2);
      } else if (rating == 2) {
        newInterval = interval == 0.0 ? 5.0 : interval * 1.2;
        newEase = max(1.3, ease - 0.15);
      } else if (rating == 3) {
        newInterval = interval == 0.0 ? 10.0 : (interval * ease);
      } else if (rating == 4) {
        newInterval = interval == 0.0 ? 15.0 : (interval * ease * 1.3);
        newEase = ease + 0.15;
      }

      if (rating > 1) {
        newInterval = max(1.0, newInterval * retentionFactor);
      }

      // Arrondir l'intervalle et la facilité
      newInterval = double.parse(newInterval.toStringAsFixed(1));
      newEase = double.parse(newEase.toStringAsFixed(2));

      final dueDate = now.add(Duration(
        seconds: (newInterval * 60).round(),
      ));

      return FsrsResult(
        reps: newReps,
        interval: newInterval,
        ease: newEase,
        dueDate: dueDate,
      );
    } else {
      // --- MODE LONG TERME (Jours) ---
      if (rating == 1) {
        newInterval = 1.0;
        newEase = max(1.3, ease - 0.2);
      } else if (rating == 2) {
        newInterval = interval == 0.0 ? 1.0 : interval * 1.2;
        newEase = max(1.3, ease - 0.15);
      } else if (rating == 3) {
        if (interval == 0.0) {
          newInterval = 1.0;
        } else if (interval == 1.0) {
          newInterval = 3.0;
        } else {
          newInterval = interval * ease;
        }
      } else if (rating == 4) {
        newInterval = interval == 0.0 ? 4.0 : (interval * ease * 1.3);
        newEase = ease + 0.15;
      }

      if (rating > 1) {
        newInterval = max(1.0, newInterval * retentionFactor);
      }

      newInterval = double.parse(newInterval.toStringAsFixed(1));
      newEase = double.parse(newEase.toStringAsFixed(2));

      final dueDate = now.add(Duration(
        seconds: (newInterval * 86400).round(),
      ));

      return FsrsResult(
        reps: newReps,
        interval: newInterval,
        ease: newEase,
        dueDate: dueDate,
      );
    }
  }

  /// Calcule le seuil critique de cartes en attente avant notification
  /// Tient compte du taux de rétention cible : plus le taux est élevé, plus le seuil est réactif
  static int calculateCriticalThreshold(int totalCards, {double desiredRetention = 0.90}) {
    if (totalCards <= 0) return 0;
    final clampedR = desiredRetention.clamp(0.70, 0.98);
    final tolerance = (1.0 - clampedR) * 2;
    return max(3, (totalCards * tolerance).round());
  }

  /// Trouve la date exacte à laquelle le seuil critique de cartes dues sera franchi
  static DateTime? findCriticalDueDate({
    required List<DateTime> dueDates,
    required int totalCards,
    double desiredRetention = 0.90,
  }) {
    final threshold = calculateCriticalThreshold(totalCards, desiredRetention: desiredRetention);
    if (threshold == 0 || dueDates.length < threshold) return null;

    final sortedDates = List<DateTime>.from(dueDates)..sort();
    // Le seuil est atteint à la date de la [threshold - 1]-ième carte due
    return sortedDates[threshold - 1];
  }

  /// Transpose intelligemment les métriques FSRS d'une carte lors d'un changement de mode de paquet.
  /// - Colles (Minutes) -> Long Terme (Jours) :
  ///   Si la carte est nouvelle ou peu révisée (< 5 min), interval = 0, dueDate = now.
  ///   Si elle est consolidée en session intensive (reps >= 2), elle démarre à 1 ou 2 jours.
  ///   La facilité (ease) acquise est rigoureusement conservée.
  /// - Long Terme (Jours) -> Colles (Minutes) :
  ///   Pour un bachotage immédiat, l'intervalle est réinitialisé à 0 et dueDate = now,
  ///   afin que toutes les cartes soient immédiatement révisables, tout en conservant
  ///   la facilité acquise (ease) pour que les bonnes réponses grimpent vite.
  static void transposeCardMode({
    required Flashcard card,
    required bool toLongTermDays,
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();

    if (toLongTermDays) {
      if (card.reps == 0 || card.interval < 5.0) {
        card.interval = 0.0;
        card.dueDate = now;
      } else {
        final double days = card.reps >= 3 ? min(3.0, (card.reps / 2).roundToDouble()) : 1.0;
        card.interval = days;
        card.dueDate = now.add(Duration(days: days.round()));
      }
    } else {
      card.interval = 0.0;
      card.dueDate = now;
    }
  }
}
