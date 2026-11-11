import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_flashcards/widgets/adaptive_text.dart';
import 'package:learn_flashcards/widgets/flip_card_3d.dart';
import 'package:learn_flashcards/widgets/kawaii_button.dart';

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
}
