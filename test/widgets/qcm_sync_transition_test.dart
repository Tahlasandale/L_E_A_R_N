import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:learn_flashcards/models/deck.dart';
import 'package:learn_flashcards/models/flashcard.dart';
import 'package:learn_flashcards/providers/deck_provider.dart';
import 'package:learn_flashcards/providers/review_provider.dart';
import 'package:learn_flashcards/providers/settings_provider.dart';
import 'package:learn_flashcards/screens/qcm_screen.dart';
import 'package:learn_flashcards/services/storage_service.dart';

class _MockStorageService extends StorageService {
  final List<Flashcard> savedCards = [];

  @override
  Future<List<Deck>> getAllDecks() async => [];

  @override
  Future<List<Flashcard>> getAllCards() async => [];

  @override
  Future<void> saveCard(Flashcard card) async {
    savedCards.add(card);
  }
}

Widget _buildTestApp({
  required Widget child,
  required StorageService storage,
  required DeckProvider deckProvider,
  required ReviewProvider reviewProvider,
  required SettingsProvider settingsProvider,
}) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<DeckProvider>.value(value: deckProvider),
      ChangeNotifierProvider<ReviewProvider>.value(value: reviewProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  testWidgets('QcmScreen synchronise parfaitement la transition question et réponses', (WidgetTester tester) async {
    final mockStorage = _MockStorageService();
    final deckProvider = DeckProvider(mockStorage);
    final reviewProvider = ReviewProvider();
    final settingsProvider = SettingsProvider();

    final card1 = Flashcard()
      ..id = 1
      ..front = 'Capitale France ?'
      ..back = 'Paris'
      ..reps = 0
      ..interval = 0
      ..ease = 2.5;

    final card2 = Flashcard()
      ..id = 2
      ..front = 'Capitale Japon ?'
      ..back = 'Tokyo'
      ..reps = 0
      ..interval = 0
      ..ease = 2.5;

    final card3 = Flashcard()
      ..id = 3
      ..front = 'Capitale UK ?'
      ..back = 'Londres'
      ..reps = 0
      ..interval = 0
      ..ease = 2.5;

    final card4 = Flashcard()
      ..id = 4
      ..front = 'Capitale Allemagne ?'
      ..back = 'Berlin'
      ..reps = 0
      ..interval = 0
      ..ease = 2.5;

    final poolCards = [card1, card2, card3, card4];

    reviewProvider.initSession(cards: [card1, card2]);

    await tester.pumpWidget(_buildTestApp(
      child: QcmScreen(
        poolCards: poolCards,
        isIntensiveMinutes: true,
      ),
      storage: mockStorage,
      deckProvider: deckProvider,
      reviewProvider: reviewProvider,
      settingsProvider: settingsProvider,
    ));

    await tester.pumpAndSettle();

    // 1. État initial : la question 1 est visible, pas la question 2
    expect(find.text('Capitale France ?'), findsOneWidget);
    expect(find.text('Capitale Japon ?'), findsNothing);
    expect(find.text('Paris'), findsOneWidget);

    // 2. L'utilisateur clique sur la réponse "Paris"
    await tester.tap(find.text('Paris'));
    await tester.pump(const Duration(milliseconds: 100));

    // Phase 1 : Pendant le feedback (450ms), la question 1 DOIT rester affichée
    expect(find.text('Capitale France ?'), findsOneWidget);
    expect(find.text('Capitale Japon ?'), findsNothing);

    // 3. Avancer dans Phase 2 (Affichage de la bonne réponse en grand)
    await tester.pump(const Duration(milliseconds: 400)); // t = 500ms total
    expect(find.text('Capitale France ?'), findsOneWidget);
    expect(find.text('Capitale Japon ?'), findsNothing);
    expect(find.text('EXCELLENT ! 🎉'), findsOneWidget);

    // 4. Avancer encore pendant Phase 2 (avant la fin de la durée configurée de 1s)
    await tester.pump(const Duration(milliseconds: 500)); // t = 1000ms
    expect(find.text('Capitale France ?'), findsOneWidget);
    expect(find.text('Capitale Japon ?'), findsNothing);

    // 5. Franchir la fin de Phase 2 (1450ms total) : Transition simultanée !
    await tester.pump(const Duration(milliseconds: 600)); // t = 1600ms
    await tester.pumpAndSettle();

    // La Question 2 et ses choix doivent être apparus ENSEMBLE !
    expect(find.text('Capitale France ?'), findsNothing);
    expect(find.text('Capitale Japon ?'), findsOneWidget);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(mockStorage.savedCards.length, 1);
    expect(mockStorage.savedCards[0].id, 1);
  });

  testWidgets('QcmScreen persiste la notation en attente si le widget est démonté avant la fin du timer', (WidgetTester tester) async {
    final mockStorage = _MockStorageService();
    final deckProvider = DeckProvider(mockStorage);
    final reviewProvider = ReviewProvider();
    final settingsProvider = SettingsProvider();

    final card1 = Flashcard()
      ..id = 1
      ..front = 'Question 1'
      ..back = 'Reponse 1'
      ..reps = 0
      ..interval = 0
      ..ease = 2.5;

    final card2 = Flashcard()
      ..id = 2
      ..front = 'Question 2'
      ..back = 'Reponse 2'
      ..reps = 0
      ..interval = 0
      ..ease = 2.5;

    final poolCards = [
      card1,
      card2,
      Flashcard()..id = 3..front = 'Q3'..back = 'R3',
      Flashcard()..id = 4..front = 'Q4'..back = 'R4',
    ];

    reviewProvider.initSession(cards: [card1, card2]);

    await tester.pumpWidget(_buildTestApp(
      child: QcmScreen(
        poolCards: poolCards,
        isIntensiveMinutes: true,
      ),
      storage: mockStorage,
      deckProvider: deckProvider,
      reviewProvider: reviewProvider,
      settingsProvider: settingsProvider,
    ));

    await tester.pumpAndSettle();

    // Cliquer sur la réponse
    await tester.tap(find.text('Reponse 1'));
    await tester.pump(const Duration(milliseconds: 200));

    // À t=200ms, la notation n'a pas encore été déclenchée
    expect(mockStorage.savedCards.isEmpty, isTrue);

    // Démonter le widget (équivalent Navigator.pop)
    await tester.pumpWidget(const SizedBox());

    // dispose() doit exécuter _pendingRateCallback
    expect(mockStorage.savedCards.length, 1);
    expect(mockStorage.savedCards[0].id, 1);
  });
}
