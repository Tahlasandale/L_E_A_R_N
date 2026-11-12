import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/deck.dart';
import 'models/flashcard.dart';
import 'providers/deck_provider.dart';
import 'providers/review_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/deck_detail_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/qcm_screen.dart';
import 'screens/review_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/catppuccin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation sécurisée des services avec capture d'erreurs
  final storage = StorageService();
  try {
    await storage.init();
  } catch (e) {
    debugPrint('StorageService init error: $e');
  }

  if (kIsWeb) {
    try {
      if (Uri.base.queryParameters['demo'] == 'true') {
        final d1 = await storage.createDeck('Maths (Trigo) 📐', mode: FsrsMode.intensiveMinutes);
        final d2 = await storage.createDeck('Japonais (Kanji) 🇯🇵', mode: FsrsMode.longTermDays);
        final d3 = await storage.createDeck('Physique ⚡', mode: FsrsMode.longTermDays);

        final card1 = Flashcard()..id = 1..front = 'cos(π / 2)'..back = '0'..dueDate = DateTime.now();
        final card2 = Flashcard()..id = 2..front = 'sin(π / 6)'..back = '1/2'..dueDate = DateTime.now();
        final card3 = Flashcard()..id = 3..front = 'tan(π / 4)'..back = '1'..dueDate = DateTime.now();
        final card4 = Flashcard()..id = 4..front = 'cos(0)'..back = '1'..dueDate = DateTime.now();
        await storage.addCardsToDeck([card1, card2, card3, card4], d1);

        final cardJ1 = Flashcard()..id = 5..front = '猫 (Neko)'..back = 'Chat 🐾'..dueDate = DateTime.now();
        final cardJ2 = Flashcard()..id = 6..front = '桜 (Sakura)'..back = 'Cerisier en fleur 🌸'..dueDate = DateTime.now();
        await storage.addCardsToDeck([cardJ1, cardJ2], d2);

        final cardP1 = Flashcard()..id = 7..front = 'Énergie au repos'..back = 'E = mc²'..dueDate = DateTime.now();
        final cardP2 = Flashcard()..id = 8..front = 'Loi d\'Ohm'..back = 'U = R × I'..dueDate = DateTime.now();
        await storage.addCardsToDeck([cardP1, cardP2], d3);
      }
    } catch (e) {
      debugPrint('Web demo data error: $e');
    }
  }

  final notificationService = NotificationService();
  try {
    await notificationService.init();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  final settingsProvider = SettingsProvider();
  try {
    await settingsProvider.init();
  } catch (e) {
    debugPrint('SettingsProvider init error: $e');
  }

  final deckProvider = DeckProvider(storage);
  final reviewProvider = ReviewProvider();

  Widget homeWidget = const MainNavigationScreen();
  if (kIsWeb) {
    try {
      final screen = Uri.base.queryParameters['screen'];
      final tab = Uri.base.queryParameters['tab'];
      if (tab != null) {
        final tabIdx = int.tryParse(tab) ?? 0;
        homeWidget = MainNavigationScreen(initialIndex: tabIdx);
      } else if (screen == 'review') {
        final cards = await storage.getAllCards();
        reviewProvider.initSession(cards: cards.isNotEmpty ? cards : [
          Flashcard()..front = 'cos(π / 2)'..back = '0'..dueDate = DateTime.now(),
        ]);
        homeWidget = const ReviewScreen(isIntensiveMinutes: true);
      } else if (screen == 'qcm') {
        final cards = await storage.getAllCards();
        reviewProvider.initSession(cards: cards);
        homeWidget = QcmScreen(poolCards: cards, isIntensiveMinutes: true);
      } else if (screen == 'decks') {
        homeWidget = const MainNavigationScreen(initialIndex: 1);
      } else if (screen == 'settings') {
        homeWidget = const MainNavigationScreen(initialIndex: 2);
      } else if (screen == 'detail') {
        await deckProvider.loadDecks();
        final deck = deckProvider.decks.isNotEmpty ? deckProvider.decks.first : (Deck()..name = 'Maths (Trigo) 📐');
        homeWidget = DeckDetailScreen(deck: deck);
      }
    } catch (e) {
      debugPrint('Web routing error: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<DeckProvider>.value(value: deckProvider),
        ChangeNotifierProvider<ReviewProvider>.value(value: reviewProvider),
      ],
      child: KawaiiApp(homeWidget: homeWidget),
    ),
  );
}

class KawaiiApp extends StatelessWidget {
  final Widget? homeWidget;
  const KawaiiApp({super.key, this.homeWidget});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kawaii Flashcards',
      debugShowCheckedModeBanner: false,
      theme: Catppuccin.themeData,
      builder: kIsWeb
          ? (context, child) {
              return Container(
                color: const Color(0xFF11111B),
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: child != null ? ClipRect(child: child) : const SizedBox.shrink(),
                ),
              );
            }
          : null,
      home: homeWidget ?? const MainNavigationScreen(),
    );
  }
}
