import 'package:flutter_test/flutter_test.dart';
import 'package:learn_flashcards/models/flashcard.dart';
import 'package:learn_flashcards/services/fsrs_service.dart';

void main() {
  group('FsrsService - Mode Colles (Intensif Minutes)', () {
    test('Rating 1 (Again) réinitialise l\'intervalle à 1 minute et baisse la facilité', () {
      final now = DateTime(2026, 11, 11, 12, 0);
      final result = FsrsService.calculateNextReview(
        reps: 2,
        interval: 10.0,
        ease: 2.5,
        rating: 1,
        isIntensiveMinutes: true,
        referenceTime: now,
      );

      expect(result.reps, 3);
      expect(result.interval, 1.0);
      expect(result.ease, 2.3);
      expect(result.dueDate, now.add(const Duration(minutes: 1)));
    });

    test('Rating 2 (Hard) applique le multiplicateur 1.2 et baisse légèrement la facilité', () {
      final now = DateTime(2026, 11, 11, 12, 0);
      final result = FsrsService.calculateNextReview(
        reps: 0,
        interval: 0.0,
        ease: 2.5,
        rating: 2,
        isIntensiveMinutes: true,
        referenceTime: now,
      );

      expect(result.reps, 1);
      expect(result.interval, 5.0);
      expect(result.ease, 2.35);
      expect(result.dueDate, now.add(const Duration(minutes: 5)));
    });

    test('Rating 3 (Good) applique interval * ease', () {
      final now = DateTime(2026, 11, 11, 12, 0);
      final result = FsrsService.calculateNextReview(
        reps: 1,
        interval: 10.0,
        ease: 2.5,
        rating: 3,
        isIntensiveMinutes: true,
        referenceTime: now,
      );

      expect(result.reps, 2);
      expect(result.interval, 25.0); // 10 * 2.5
      expect(result.ease, 2.5);
      expect(result.dueDate, now.add(const Duration(minutes: 25)));
    });

    test('Rating 4 (Easy) applique le bonus 1.3 et augmente la facilité', () {
      final now = DateTime(2026, 11, 11, 12, 0);
      final result = FsrsService.calculateNextReview(
        reps: 0,
        interval: 0.0,
        ease: 2.5,
        rating: 4,
        isIntensiveMinutes: true,
        referenceTime: now,
      );

      expect(result.reps, 1);
      expect(result.interval, 15.0);
      expect(result.ease, 2.65);
      expect(result.dueDate, now.add(const Duration(minutes: 15)));
    });

    test('La facilité (ease) ne descend jamais sous 1.3', () {
      final result = FsrsService.calculateNextReview(
        reps: 10,
        interval: 1.0,
        ease: 1.35,
        rating: 1,
        isIntensiveMinutes: true,
      );

      expect(result.ease, 1.3);
    });
  });

  group('FsrsService - Mode Long Terme (Jours)', () {
    test('Rating 3 (Good) pour une nouvelle carte démarre à 1 jour', () {
      final now = DateTime(2026, 11, 11, 12, 0);
      final result = FsrsService.calculateNextReview(
        reps: 0,
        interval: 0.0,
        ease: 2.5,
        rating: 3,
        isIntensiveMinutes: false,
        referenceTime: now,
      );

      expect(result.interval, 1.0);
      expect(result.dueDate, now.add(const Duration(days: 1)));
    });

    test('Rating 3 (Good) pour une carte à 1 jour passe à 3 jours', () {
      final now = DateTime(2026, 11, 11, 12, 0);
      final result = FsrsService.calculateNextReview(
        reps: 1,
        interval: 1.0,
        ease: 2.5,
        rating: 3,
        isIntensiveMinutes: false,
        referenceTime: now,
      );

      expect(result.interval, 3.0);
      expect(result.dueDate, now.add(const Duration(days: 3)));
    });
  });

  group('FsrsService - Calcul du Seuil Critique & Date de Notification', () {
    test('Calcule le seuil critique (environ 20% du total, minimum 3)', () {
      expect(FsrsService.calculateCriticalThreshold(0), 0);
      expect(FsrsService.calculateCriticalThreshold(5), 3);
      expect(FsrsService.calculateCriticalThreshold(20), 4);
      expect(FsrsService.calculateCriticalThreshold(100), 20);
    });

    test('Identifie l\'instant exact où le seuil critique sera atteint', () {
      final t0 = DateTime(2026, 11, 11, 10, 0);
      final t1 = DateTime(2026, 11, 11, 11, 0);
      final t2 = DateTime(2026, 11, 11, 14, 0);
      final t3 = DateTime(2026, 11, 11, 18, 0);

      // Total 10 cartes => seuil critique = 3 cartes
      final dueDates = [t0, t1, t2, t3];
      final targetDate = FsrsService.findCriticalDueDate(
        dueDates: dueDates,
        totalCards: 10,
      );

      // La 3ème carte due est t2 (14:00)
      expect(targetDate, t2);
    });
  });

  group('FsrsService - Transposition Intelligente de Mode', () {
    test('Bascule Minutes -> Jours réinitialise une carte neuve ou peu révisée', () {
      final now = DateTime(2026, 11, 11, 10, 0);
      final card = Flashcard()
        ..reps = 0
        ..interval = 1.0
        ..ease = 2.5
        ..dueDate = now;

      FsrsService.transposeCardMode(
        card: card,
        toLongTermDays: true,
        referenceTime: now,
      );

      expect(card.interval, 0.0);
      expect(card.dueDate, now);
      expect(card.ease, 2.5);
    });

    test('Bascule Minutes -> Jours convertit une carte maîtrisée en jours selon ses répétitions', () {
      final now = DateTime(2026, 11, 11, 10, 0);
      final card = Flashcard()
        ..reps = 4
        ..interval = 25.0
        ..ease = 2.65
        ..dueDate = now;

      FsrsService.transposeCardMode(
        card: card,
        toLongTermDays: true,
        referenceTime: now,
      );

      expect(card.interval, 2.0); // min(3.0, (4/2)) = 2.0 jours
      expect(card.dueDate, now.add(const Duration(days: 2)));
      expect(card.ease, 2.65); // facilité préservée
    });

    test('Bascule Jours -> Minutes rend les cartes immédiatement révisables pour bachoter', () {
      final now = DateTime(2026, 11, 11, 10, 0);
      final card = Flashcard()
        ..reps = 5
        ..interval = 14.0 // 14 jours
        ..ease = 2.8
        ..dueDate = now.add(const Duration(days: 7));

      FsrsService.transposeCardMode(
        card: card,
        toLongTermDays: false,
        referenceTime: now,
      );

      expect(card.interval, 0.0); // prête à réviser tout de suite
      expect(card.dueDate, now);
      expect(card.ease, 2.8); // facilité préservée
    });
  });

  group('FsrsService - Taux de Rétention Paramétrable', () {
    test('Un taux de rétention élevé (95%) raccourcit les intervalles pour minimiser l\'oubli', () {
      final now = DateTime(2026, 11, 11, 10, 0);

      final resultStandard = FsrsService.calculateNextReview(
        reps: 2,
        interval: 10.0,
        ease: 2.5,
        rating: 3,
        isIntensiveMinutes: false,
        desiredRetention: 0.90, // Baseline standard
        referenceTime: now,
      );

      final resultHighRetention = FsrsService.calculateNextReview(
        reps: 2,
        interval: 10.0,
        ease: 2.5,
        rating: 3,
        isIntensiveMinutes: false,
        desiredRetention: 0.95, // Rétention forte
        referenceTime: now,
      );

      // 10 * 2.5 = 25 jours en baseline. À 95% de rétention, l'intervalle est réduit de moitié (~12.2 jours)
      expect(resultStandard.interval, 25.0);
      expect(resultHighRetention.interval < resultStandard.interval, isTrue);
      expect(resultHighRetention.interval, 12.2);
    });

    test('Un taux de rétention réduit (80%) allonge les intervalles pour espacer la charge de travail', () {
      final now = DateTime(2026, 11, 11, 10, 0);

      final resultStandard = FsrsService.calculateNextReview(
        reps: 2,
        interval: 10.0,
        ease: 2.5,
        rating: 3,
        isIntensiveMinutes: false,
        desiredRetention: 0.90,
        referenceTime: now,
      );

      final resultLowRetention = FsrsService.calculateNextReview(
        reps: 2,
        interval: 10.0,
        ease: 2.5,
        rating: 3,
        isIntensiveMinutes: false,
        desiredRetention: 0.80,
        referenceTime: now,
      );

      expect(resultLowRetention.interval > resultStandard.interval, isTrue);
      expect(resultLowRetention.interval, 52.9);
    });

    test('Le seuil critique de cartes dues est plus réactif avec une rétention élevée', () {
      final threshold90 = FsrsService.calculateCriticalThreshold(100, desiredRetention: 0.90);
      final threshold95 = FsrsService.calculateCriticalThreshold(100, desiredRetention: 0.95);
      final threshold80 = FsrsService.calculateCriticalThreshold(100, desiredRetention: 0.80);

      // À 95% de rétention, le seuil tolère moins de cartes dues (10 cartes) qu'à 80% (40 cartes)
      expect(threshold95 < threshold90, isTrue);
      expect(threshold90 < threshold80, isTrue);
    });
  });
}
