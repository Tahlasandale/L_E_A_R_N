import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:learn_flashcards/models/deck.dart';
import 'package:learn_flashcards/models/flashcard.dart';
import 'package:learn_flashcards/providers/deck_provider.dart';
import 'package:learn_flashcards/providers/review_provider.dart';
import 'package:learn_flashcards/screens/main_navigation_screen.dart';
import 'package:learn_flashcards/services/storage_service.dart';
import 'package:learn_flashcards/widgets/adaptive_text.dart';
import 'package:learn_flashcards/widgets/flip_card_3d.dart';
import 'package:learn_flashcards/widgets/kawaii_button.dart';

class _FakeStorageService extends StorageService {
  @override
  Future<List<Deck>> getAllDecks() async => [];

  @override
  Future<List<Flashcard>> getAllCards() async => [];
}

void main() {
  testWidgets('KawaiiButton réagit au clic et affiche son contenu', (WidgetTester tester) async {
    bool clicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: KawaiiButton(
              onPressed: () => clicked = true,
              child: const Text('Bouton Test'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bouton Test'), findsOneWidget);

    await tester.tap(find.text('Bouton Test'));
    await tester.pumpAndSettle();

    expect(clicked, isTrue);
  });

  testWidgets('FlipCard3D affiche la question et déclenche le retournement', (WidgetTester tester) async {
    bool flipped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FlipCard3D(
              frontText: 'Question Front',
              backText: 'Réponse Back',
              isFlipped: false,
              onFlip: () => flipped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Question Front'), findsOneWidget);
    expect(find.text('QUESTION'), findsOneWidget);

    // Tap pour retourner
    await tester.tap(find.text('Question Front'));
    await tester.pumpAndSettle();

    expect(flipped, isTrue);
  });

  testWidgets('AdaptiveText affiche le texte sur une ligne sans déborder', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              child: AdaptiveText('Texte très long pour tester l\'ajustement'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Texte très long pour tester l\'ajustement'), findsOneWidget);
  });

  testWidgets('MainNavigationScreen permet de naviguer au swipe entre Accueil, Mes Paquets et Réglages', (WidgetTester tester) async {
    final fakeStorage = _FakeStorageService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DeckProvider(fakeStorage)),
          ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ],
        child: const MaterialApp(
          home: MainNavigationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Au départ, sur l'accueil
    expect(find.text('Flashcards ⚡'), findsOneWidget);
    expect(find.text('Nouveau Paquet 📚'), findsNothing);
    expect(find.text('Rappels Prédictifs FSRS'), findsNothing);

    // Swipe vers la gauche (doigt va de droite à gauche -> affiche Mes Paquets)
    await tester.drag(find.byType(PageView), const Offset(-450, 0));
    await tester.pumpAndSettle();

    expect(find.text('Mes Paquets 📚'), findsOneWidget);

    // Swipe vers la gauche à nouveau -> affiche Réglages
    await tester.drag(find.byType(PageView), const Offset(-450, 0));
    await tester.pumpAndSettle();

    expect(find.text('Rappels Prédictifs FSRS'), findsOneWidget);

    // Swipe vers la droite -> revient à Mes Paquets
    await tester.drag(find.byType(PageView), const Offset(450, 0));
    await tester.pumpAndSettle();

    expect(find.text('Mes Paquets 📚'), findsOneWidget);

    // Tap sur le bouton Accueil de la barre de navigation
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();

    expect(find.text('Flashcards ⚡'), findsOneWidget);
  });
}
