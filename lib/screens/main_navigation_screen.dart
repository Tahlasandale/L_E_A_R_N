import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/deck_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/catppuccin.dart';
import 'dashboard_screen.dart';
import 'deck_manager_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  late int _currentIndex;
  late final PageController _pageController;

  late final List<Widget> _screens = const [
    _KeepAlivePage(child: DashboardScreen()),
    _KeepAlivePage(child: DeckManagerScreen()),
    _KeepAlivePage(child: SettingsScreen()),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addObserver(this);
    // Charger les paquets au démarrage et notifier si auto-restauration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deckProvider = Provider.of<DeckProvider>(context, listen: false);
      final storage = Provider.of<StorageService>(context, listen: false);
      deckProvider.loadDecks();

      if (storage.didAutoRestoreFromMirror && mounted) {
        storage.didAutoRestoreFromMirror = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Catppuccin.mantle,
            duration: Duration(seconds: 4),
            content: Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: Catppuccin.green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✨ Données et progression restaurées automatiquement depuis le miroir JSON !',
                    style: TextStyle(color: Catppuccin.green, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Lorsque l'application passe en arrière-plan, programmer la notification prédictive (uniquement sur paquets actifs)
      final provider = Provider.of<DeckProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final activeCards = provider.getActiveCardsPool();
      NotificationService().scheduleOnAppPause(
        allCards: activeCards,
        desiredRetention: settingsProvider.desiredRetention,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Catppuccin.surface0, width: 2)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Catppuccin.crust,
          selectedItemColor: Catppuccin.sky,
          unselectedItemColor: Catppuccin.overlay,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          onTap: (index) {
            setState(() => _currentIndex = index);
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
            );
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.flash_on),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.style),
              label: 'Mes Paquets',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Réglages',
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
