import 'package:flutter_test/flutter_test.dart';
import 'package:learn_flashcards/providers/streak_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StreakProvider - Règles de Streak avec tolérance 2 jours', () {
    late StreakProvider streakProvider;

    setUp(() {
      streakProvider = StreakProvider();
    });

    test('État initial sans révision : streak 0, non révisé, pas en danger', () {
      expect(streakProvider.currentStreak, 0);
      expect(streakProvider.bestStreak, 0);
      expect(streakProvider.reviewedToday, false);
      expect(streakProvider.isAtRisk, false);
      expect(streakProvider.lastReviewDate, isNull);
    });

    test('Première révision : streak passe à 1 et bestStreak à 1', () async {
      final today = DateTime(2026, 11, 16, 10, 30);
      await streakProvider.recordReview(nowOverride: today);

      expect(streakProvider.currentStreak, 1);
      expect(streakProvider.bestStreak, 1);
      expect(streakProvider.reviewedToday, true);
      expect(streakProvider.isAtRisk, false);
      expect(streakProvider.lastReviewDate, DateTime(2026, 11, 16));
    });

    test('Deuxième révision le même jour : streak ne s\'incrémente pas plusieurs fois', () async {
      final morning = DateTime(2026, 11, 16, 8, 0);
      final evening = DateTime(2026, 11, 16, 20, 0);

      await streakProvider.recordReview(nowOverride: morning);
      expect(streakProvider.currentStreak, 1);

      await streakProvider.recordReview(nowOverride: evening);
      expect(streakProvider.currentStreak, 1);
      expect(streakProvider.bestStreak, 1);
      expect(streakProvider.reviewedToday, true);
    });

    test('Révision le lendemain (diff == 1) : streak passe à 2', () async {
      final day1 = DateTime(2026, 11, 16, 14, 0);
      final day2 = DateTime(2026, 11, 17, 9, 0);

      await streakProvider.recordReview(nowOverride: day1);
      expect(streakProvider.currentStreak, 1);

      // Le matin du jour 2 avant de réviser
      streakProvider.checkStreakStatus(nowOverride: day2);
      expect(streakProvider.currentStreak, 1);
      expect(streakProvider.reviewedToday, false);
      expect(streakProvider.isAtRisk, false);

      // Révision du jour 2
      await streakProvider.recordReview(nowOverride: day2);
      expect(streakProvider.currentStreak, 2);
      expect(streakProvider.bestStreak, 2);
      expect(streakProvider.reviewedToday, true);
    });

    test('Saut de 1 jour (diff == 2) : streak préservée, passe en isAtRisk = true, puis continue', () async {
      final day1 = DateTime(2026, 11, 16, 12, 0);
      await streakProvider.recordReview(nowOverride: day1);

      // Jour 2 sauté ! (2026-11-17)
      // Jour 3 (avant révision) : 1 jour a été sauté (le 17)
      final day3Morning = DateTime(2026, 11, 18, 9, 0);
      streakProvider.checkStreakStatus(nowOverride: day3Morning);

      // Tolérance 2 jours : la série N'EST PAS rompue, mais est en danger !
      expect(streakProvider.currentStreak, 1);
      expect(streakProvider.reviewedToday, false);
      expect(streakProvider.isAtRisk, true);

      // L'utilisateur révise le jour 3 : la série est sauvée et continue !
      await streakProvider.recordReview(nowOverride: day3Morning);
      expect(streakProvider.currentStreak, 2);
      expect(streakProvider.bestStreak, 2);
      expect(streakProvider.reviewedToday, true);
      expect(streakProvider.isAtRisk, false);
    });

    test('Saut de 2 jours consécutifs (diff == 3) : la série se rompt (0), puis repart à 1', () async {
      final day1 = DateTime(2026, 11, 16, 12, 0);
      await streakProvider.recordReview(nowOverride: day1);
      // Révision jour 2
      final day2 = DateTime(2026, 11, 17, 12, 0);
      await streakProvider.recordReview(nowOverride: day2);
      expect(streakProvider.currentStreak, 2);
      expect(streakProvider.bestStreak, 2);

      // Jour 3 (le 18) sauté, jour 4 (le 19) sauté -> 2 jours consécutifs sautés !
      // Le jour 5 (le 20) :
      final day5 = DateTime(2026, 11, 20, 10, 0);
      streakProvider.checkStreakStatus(nowOverride: day5);

      // La série est rompue !
      expect(streakProvider.currentStreak, 0);
      expect(streakProvider.reviewedToday, false);
      expect(streakProvider.isAtRisk, false);
      // Mais le bestStreak est préservé !
      expect(streakProvider.bestStreak, 2);

      // Nouvelle révision après rupture : la série redémarre à 1
      await streakProvider.recordReview(nowOverride: day5);
      expect(streakProvider.currentStreak, 1);
      expect(streakProvider.bestStreak, 2);
      expect(streakProvider.reviewedToday, true);
    });

    test('Export / Import JSON sérialise fidèlement la streak', () {
      final streak = StreakProvider();
      streak.resetForTest(
        currentStreak: 5,
        bestStreak: 12,
        lastReviewDate: DateTime(2026, 11, 15),
      );

      final json = streak.toJson();
      expect(json['currentStreak'], 5);
      expect(json['bestStreak'], 12);
      expect(json['lastReviewDate'], contains('2026-11-15'));

      final restored = StreakProvider();
      restored.importJson(json);
      expect(restored.currentStreak, 5);
      expect(restored.bestStreak, 12);
    });
  });
}
