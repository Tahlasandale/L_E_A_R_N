import 'dart:math';

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
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();
    int newReps = reps + 1;
    double newEase = ease;
    double newInterval = interval;

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

      // Arrondir la facilité à 2 décimales pour éviter les dérives de float
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
  /// Représente ~20% du paquet avec un minimum de 3 cartes
  static int calculateCriticalThreshold(int totalCards) {
    if (totalCards <= 0) return 0;
    return max(3, (totalCards * 0.2).round());
  }

  /// Trouve la date exacte à laquelle le seuil critique de cartes dues sera franchi
  static DateTime? findCriticalDueDate({
    required List<DateTime> dueDates,
    required int totalCards,
  }) {
    final threshold = calculateCriticalThreshold(totalCards);
    if (threshold == 0 || dueDates.length < threshold) return null;

    final sortedDates = List<DateTime>.from(dueDates)..sort();
    // Le seuil est atteint à la date de la [threshold - 1]-ième carte due
    return sortedDates[threshold - 1];
  }
}
