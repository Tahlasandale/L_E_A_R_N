import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/deck_provider.dart';
import 'providers/review_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/catppuccin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation des services
  final storage = StorageService();
  await storage.init();

  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<DeckProvider>(
          create: (_) => DeckProvider(storage),
        ),
        ChangeNotifierProvider<ReviewProvider>(
          create: (_) => ReviewProvider(),
        ),
      ],
      child: const KawaiiApp(),
    ),
  );
}

class KawaiiApp extends StatelessWidget {
  const KawaiiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kawaii Flashcards',
      debugShowCheckedModeBanner: false,
      theme: Catppuccin.themeData,
      home: const MainNavigationScreen(),
    );
  }
}
