import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learn_flashcards/models/deck.dart';
import 'package:learn_flashcards/models/flashcard.dart';
import 'package:learn_flashcards/providers/deck_provider.dart';
import 'package:learn_flashcards/providers/review_provider.dart';
import 'package:learn_flashcards/providers/settings_provider.dart';
import 'package:learn_flashcards/screens/dashboard_screen.dart';
import 'package:learn_flashcards/screens/deck_detail_screen.dart';
import 'package:learn_flashcards/screens/deck_manager_screen.dart';
import 'package:learn_flashcards/screens/qcm_screen.dart';
import 'package:learn_flashcards/screens/review_screen.dart';
import 'package:learn_flashcards/screens/settings_screen.dart';
import 'package:learn_flashcards/services/storage_service.dart';
import 'package:learn_flashcards/theme/catppuccin.dart';

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final fontData = file.readAsBytesSync();
  final fontLoader = FontLoader(family);
  fontLoader.addFont(Future.value(ByteData.view(
    fontData.buffer,
    fontData.offsetInBytes,
    fontData.lengthInBytes,
  )));
  await fontLoader.load();
}

Widget _wrapScreen({
  required Widget home,
  required StorageService storage,
  required DeckProvider deckProvider,
  required ReviewProvider reviewProvider,
  required SettingsProvider settingsProvider,
}) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider.value(value: settingsProvider),
      ChangeNotifierProvider.value(value: deckProvider),
      ChangeNotifierProvider.value(value: reviewProvider),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Catppuccin.themeData.copyWith(
        textTheme: Catppuccin.themeData.textTheme.apply(
          fontFamily: 'Nunito',
          fontFamilyFallback: const ['NotoColorEmoji', 'DroidSansFallback', 'DejaVuSans', 'NotoSansThai', 'Roboto'],
        ),
      ),
      home: home,
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFont('Nunito', 'test/assets/fonts/Nunito.ttf');
    await _loadFont('Roboto', 'test/assets/fonts/Roboto-Regular.ttf');
    await _loadFont('MaterialIcons', 'test/assets/fonts/MaterialIcons-Regular.otf');
    await _loadFont('DroidSansFallback', 'test/assets/fonts/DroidSansFallback.ttf');
    await _loadFont('NotoColorEmoji', 'test/assets/fonts/NotoColorEmoji.ttf');
    await _loadFont('DejaVuSans', 'test/assets/fonts/DejaVuSans.ttf');
    await _loadFont('NotoSansThai', 'test/assets/fonts/NotoSansThai.ttf');
  });

  void setMobileView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<Map<String, dynamic>> setupTestData() async {
    final storage = StorageService();

    // 1. Vocabulaire Japonais
    final deckJap = await storage.createDeck('Vocabulaire Japonais', mode: FsrsMode.intensiveMinutes);
    final japCards = [
      Flashcard()..front = '桜 (Sakura)'..back = 'Fleur de cerisier'..reps = 3..interval = 15..ease = 2.5..dueDate = DateTime.now().subtract(const Duration(minutes: 5)),
      Flashcard()..front = '猫 (Neko)'..back = 'Chat'..reps = 4..interval = 30..ease = 2.6..dueDate = DateTime.now().subtract(const Duration(minutes: 2)),
      Flashcard()..front = '水 (Mizu)'..back = 'Eau'..reps = 2..interval = 5..ease = 2.3..dueDate = DateTime.now().subtract(const Duration(minutes: 10)),
      Flashcard()..front = '山 (Yama)'..back = 'Montagne'..reps = 1..interval = 1..ease = 2.5..dueDate = DateTime.now().add(const Duration(minutes: 15)),
      Flashcard()..front = '川 (Kawa)'..back = 'Rivière'..reps = 5..interval = 60..ease = 2.7..dueDate = DateTime.now().add(const Duration(minutes: 45)),
      Flashcard()..front = '火 (Hi)'..back = 'Feu'..reps = 2..interval = 5..ease = 2.4..dueDate = DateTime.now().subtract(const Duration(minutes: 1)),
    ];
    await storage.addCardsToDeck(japCards, deckJap);

    // 2. Formules Trigonométrie
    final deckTrigo = await storage.createDeck('Formules Trigonométrie', mode: FsrsMode.intensiveMinutes);
    final trigoCards = [
      Flashcard()..front = 'cos²(x) + sin²(x)'..back = '1'..reps = 6..interval = 120..ease = 2.8..dueDate = DateTime.now().subtract(const Duration(minutes: 15)),
      Flashcard()..front = 'tan(x)'..back = 'sin(x) / cos(x)'..reps = 3..interval = 15..ease = 2.5..dueDate = DateTime.now().subtract(const Duration(minutes: 3)),
      Flashcard()..front = 'cos(2x)'..back = 'cos²(x) - sin²(x)'..reps = 2..interval = 5..ease = 2.4..dueDate = DateTime.now().add(const Duration(minutes: 30)),
    ];
    await storage.addCardsToDeck(trigoCards, deckTrigo);

    // 3. Biologie Cellulaire
    final deckBio = await storage.createDeck('Biologie Cellulaire', mode: FsrsMode.longTermDays);
    final bioCards = [
      Flashcard()..front = 'Mitochondrie'..back = 'Centrale énergétique (ATP)'..reps = 5..interval = 14..ease = 2.6..dueDate = DateTime.now().subtract(const Duration(days: 1)),
      Flashcard()..front = 'Ribosome'..back = 'Synthèse des protéines'..reps = 3..interval = 7..ease = 2.5..dueDate = DateTime.now().add(const Duration(days: 3)),
      Flashcard()..front = 'Réticulum endoplasmique'..back = 'Transport des macromolécules'..reps = 1..interval = 1..ease = 2.4..dueDate = DateTime.now().subtract(const Duration(hours: 4)),
    ];
    await storage.addCardsToDeck(bioCards, deckBio);

    // 4. Histoire Moderne (Inactif)
    final deckHist = await storage.createDeck('Histoire Moderne', mode: FsrsMode.longTermDays);
    deckHist.isActive = false;
    final histCards = [
      Flashcard()..front = 'Prise de la Bastille'..back = '14 juillet 1789'..reps = 8..interval = 45..ease = 2.8..dueDate = DateTime.now().add(const Duration(days: 10)),
    ];
    await storage.addCardsToDeck(histCards, deckHist);

    final deckProvider = DeckProvider(storage);
    await deckProvider.loadDecks();

    final settingsProvider = SettingsProvider();

    return {
      'storage': storage,
      'deckProvider': deckProvider,
      'settingsProvider': settingsProvider,
      'deckJap': deckJap,
      'deckTrigo': deckTrigo,
      'deckBio': deckBio,
      'japCards': japCards,
      'trigoCards': trigoCards,
    };
  }

  testWidgets('Screenshot: Dashboard Screen', (WidgetTester tester) async {
    setMobileView(tester);
    final data = await setupTestData();
    final deckProvider = data['deckProvider'] as DeckProvider;
    final deckJap = data['deckJap'] as Deck;
    final deckTrigo = data['deckTrigo'] as Deck;

    deckProvider.clearSelection();
    deckProvider.toggleDeckSelection(deckJap.id);
    deckProvider.toggleDeckSelection(deckTrigo.id);

    final reviewProvider = ReviewProvider();

    await tester.pumpWidget(_wrapScreen(
      home: const DashboardScreen(),
      storage: data['storage'],
      deckProvider: deckProvider,
      reviewProvider: reviewProvider,
      settingsProvider: data['settingsProvider'],
    ));

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/dashboard.png'),
    );
  });

  testWidgets('Screenshot: Decks Manager Screen', (WidgetTester tester) async {
    setMobileView(tester);
    final data = await setupTestData();
    final reviewProvider = ReviewProvider();

    await tester.pumpWidget(_wrapScreen(
      home: const DeckManagerScreen(),
      storage: data['storage'],
      deckProvider: data['deckProvider'],
      reviewProvider: reviewProvider,
      settingsProvider: data['settingsProvider'],
    ));

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/decks.png'),
    );
  });

  testWidgets('Screenshot: Deck Detail Screen', (WidgetTester tester) async {
    setMobileView(tester);
    final data = await setupTestData();
    final reviewProvider = ReviewProvider();
    final deckJap = data['deckJap'] as Deck;

    await tester.pumpWidget(_wrapScreen(
      home: DeckDetailScreen(deck: deckJap),
      storage: data['storage'],
      deckProvider: data['deckProvider'],
      reviewProvider: reviewProvider,
      settingsProvider: data['settingsProvider'],
    ));

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/deck_detail.png'),
    );
  });

  testWidgets('Screenshot: Review 3D Screen', (WidgetTester tester) async {
    setMobileView(tester);
    final data = await setupTestData();
    final japCards = data['japCards'] as List<Flashcard>;

    final reviewProvider = ReviewProvider();
    reviewProvider.initSession(cards: [japCards[0], japCards[1], japCards[2]]);
    // Retourner la carte pour afficher le verso et les 4 boutons de notation
    reviewProvider.flipCard();

    await tester.pumpWidget(_wrapScreen(
      home: const ReviewScreen(isIntensiveMinutes: true),
      storage: data['storage'],
      deckProvider: data['deckProvider'],
      reviewProvider: reviewProvider,
      settingsProvider: data['settingsProvider'],
    ));

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/review.png'),
    );
  });

  testWidgets('Screenshot: QCM 4 Lines Screen', (WidgetTester tester) async {
    setMobileView(tester);
    final data = await setupTestData();
    final japCards = data['japCards'] as List<Flashcard>;
    final trigoCards = data['trigoCards'] as List<Flashcard>;

    final reviewProvider = ReviewProvider(random: math.Random(42));
    reviewProvider.initSession(cards: [japCards[0], japCards[1]]);

    await tester.pumpWidget(_wrapScreen(
      home: QcmScreen(
        poolCards: [...japCards, ...trigoCards],
        isIntensiveMinutes: true,
      ),
      storage: data['storage'],
      deckProvider: data['deckProvider'],
      reviewProvider: reviewProvider,
      settingsProvider: data['settingsProvider'],
    ));

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/qcm.png'),
    );
  });

  testWidgets('Screenshot: Settings Screen', (WidgetTester tester) async {
    setMobileView(tester);
    final data = await setupTestData();
    final reviewProvider = ReviewProvider();

    await tester.pumpWidget(_wrapScreen(
      home: const SettingsScreen(),
      storage: data['storage'],
      deckProvider: data['deckProvider'],
      reviewProvider: reviewProvider,
      settingsProvider: data['settingsProvider'],
    ));

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/settings.png'),
    );
  });
}
