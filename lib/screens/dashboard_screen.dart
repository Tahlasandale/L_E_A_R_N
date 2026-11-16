import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../providers/review_provider.dart';
import '../providers/streak_provider.dart';
import '../theme/catppuccin.dart';
import '../widgets/kawaii_button.dart';
import 'review_screen.dart';
import 'qcm_screen.dart';
import 'csv_io_modal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isRandomOrder = false;

  void _toggleRandom() {
    setState(() {
      _isRandomOrder = !_isRandomOrder;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Catppuccin.mantle,
        duration: const Duration(seconds: 1),
        content: Text(
          _isRandomOrder
              ? '🔀 Mode Aléatoire ACTIVÉ !'
              : '⬇️ Mode Chronologique ACTIVÉ (urgences d\'abord)',
          style: const TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _startClassicReview() {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);

    var cardsToReview = deckProvider.getDueCardsForSelected();
    if (cardsToReview.isEmpty) {
      // Proposer de réviser toutes les cartes de la sélection en entraînement
      final allCards = deckProvider.getAllCardsForSelected();
      if (allCards.isEmpty) {
        _showNoCardsDialog('Aucune carte dans les paquets sélectionnés.');
        return;
      }
      _showAllCardsOptionDialog(
        title: '✨ Aucune carte en attente !',
        message: 'Tu as révisé toutes tes cartes dues. Veux-tu t\'entraîner librement sur les ${allCards.length} cartes sélectionnées ?',
        onConfirm: () {
          reviewProvider.initSession(cards: allCards, isRandomOrder: _isRandomOrder);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReviewScreen(
                isIntensiveMinutes: deckProvider.isSelectedModeIntensive,
              ),
            ),
          );
        },
      );
      return;
    }

    reviewProvider.initSession(cards: cardsToReview, isRandomOrder: _isRandomOrder);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          isIntensiveMinutes: deckProvider.isSelectedModeIntensive,
        ),
      ),
    );
  }

  void _startQcm() async {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);

    var cardsToReview = deckProvider.getDueCardsForSelected();
    if (cardsToReview.isEmpty) {
      final allCards = deckProvider.getAllCardsForSelected();
      if (allCards.isEmpty) {
        _showNoCardsDialog('Aucune carte dans les paquets sélectionnés.');
        return;
      }
      cardsToReview = allCards;
    }

    final poolCards = await deckProvider.getAllCardsPool();

    reviewProvider.initSession(cards: cardsToReview, isRandomOrder: _isRandomOrder);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QcmScreen(
          poolCards: poolCards,
          isIntensiveMinutes: deckProvider.isSelectedModeIntensive,
        ),
      ),
    );
  }

  void _showNoCardsDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Catppuccin.mantle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text('Information (◕‿◕)', style: TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Catppuccin.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Catppuccin.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAllCardsOptionDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Catppuccin.mantle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(title, style: const TextStyle(color: Catppuccin.green, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Catppuccin.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non', style: TextStyle(color: Catppuccin.overlay)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Oui, réviser ! 🚀', style: TextStyle(color: Catppuccin.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCreateDeckDialog() {
    final controller = TextEditingController();
    FsrsMode selectedMode = FsrsMode.intensiveMinutes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Catppuccin.mantle,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            title: const Text('Nouveau Paquet 📚', style: TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Catppuccin.text),
                  decoration: const InputDecoration(
                    labelText: 'Nom du paquet (ex: Maths, Japonais...)',
                    labelStyle: TextStyle(color: Catppuccin.overlay),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButton<FsrsMode>(
                  value: selectedMode,
                  dropdownColor: Catppuccin.crust,
                  style: const TextStyle(color: Catppuccin.text, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(
                      value: FsrsMode.intensiveMinutes,
                      child: Text('Mode Colles (Minutes/Heures)'),
                    ),
                    DropdownMenuItem(
                      value: FsrsMode.longTermDays,
                      child: Text('Mode Long terme (Jours)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedMode = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Catppuccin.overlay)),
              ),
              TextButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    final provider = Provider.of<DeckProvider>(context, listen: false);
                    await provider.createDeck(name, mode: selectedMode);
                    if (context.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text('Créer ⚡', style: TextStyle(color: Catppuccin.blue, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStreakBanner(StreakProvider streakProvider) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    String text;
    IconData icon;

    if (streakProvider.reviewedToday) {
      bgColor = Catppuccin.green.withValues(alpha: 0.12);
      borderColor = Catppuccin.green.withValues(alpha: 0.4);
      textColor = Catppuccin.green;
      text = '✨ Série du jour validée ! (${streakProvider.currentStreak} j consécutifs) 🎉';
      icon = Icons.check_circle_rounded;
    } else if (streakProvider.isAtRisk) {
      bgColor = Catppuccin.red.withValues(alpha: 0.15);
      borderColor = Catppuccin.red;
      textColor = Catppuccin.red;
      text = '⚠️ 1 jour sauté ! Révise aujourd\'hui pour sauver ta flamme de ${streakProvider.currentStreak} j !';
      icon = Icons.warning_amber_rounded;
    } else if (streakProvider.currentStreak > 0) {
      bgColor = Catppuccin.peach.withValues(alpha: 0.12);
      borderColor = Catppuccin.peach.withValues(alpha: 0.4);
      textColor = Catppuccin.peach;
      text = '🔥 ${streakProvider.currentStreak} jours en cours • Révise aujourd\'hui pour l\'augmenter !';
      icon = Icons.local_fire_department_rounded;
    } else {
      bgColor = Catppuccin.surface0.withValues(alpha: 0.4);
      borderColor = Catppuccin.surface0;
      textColor = Catppuccin.subtext;
      text = '🔥 0 jour • Fais une révision pour allumer ta première flamme !';
      icon = Icons.bolt_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStreakDialog(BuildContext context, StreakProvider streakProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Catppuccin.mantle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔥 Série de Révision 🔥', style: TextStyle(color: Catppuccin.peach, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              r'\(^ヮ^)/',
              style: TextStyle(fontSize: 32, color: Catppuccin.sky, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Catppuccin.crust,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Catppuccin.surface0, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${streakProvider.currentStreak}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Catppuccin.peach),
                      ),
                      const Text('Série actuelle', style: TextStyle(color: Catppuccin.subtext, fontSize: 12)),
                    ],
                  ),
                  Container(width: 2, height: 36, color: Catppuccin.surface0),
                  Column(
                    children: [
                      Text(
                        '${streakProvider.bestStreak}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Catppuccin.yellow),
                      ),
                      const Text('Record 🏆', style: TextStyle(color: Catppuccin.subtext, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '💡 Règle de Tolérance :\nTa série continue si tu révises au moins une carte par jour.\nTu peux sauter 1 jour sans pénalité : la flamme ne s\'éteint que si tu manques 2 jours consécutifs !',
              textAlign: TextAlign.center,
              style: TextStyle(color: Catppuccin.text, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Super ! ⚡', style: TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = Provider.of<DeckProvider>(context);
    final streakProvider = Provider.of<StreakProvider>(context);
    final decks = deckProvider.decks;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Flashcards ⚡',
          style: TextStyle(
            color: Catppuccin.sky,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: Text(
              _isRandomOrder ? '🔀' : '⬇️',
              style: const TextStyle(fontSize: 20),
            ),
            tooltip: _isRandomOrder ? 'Ordre Aléatoire' : 'Ordre Chronologique',
            onPressed: _toggleRandom,
          ),
          InkWell(
            onTap: () => _showStreakDialog(context, streakProvider),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: streakProvider.reviewedToday
                    ? Catppuccin.green.withValues(alpha: 0.15)
                    : streakProvider.isAtRisk
                        ? Catppuccin.red.withValues(alpha: 0.15)
                        : Catppuccin.peach.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: streakProvider.reviewedToday
                      ? Catppuccin.green
                      : streakProvider.isAtRisk
                          ? Catppuccin.red
                          : Catppuccin.peach,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    streakProvider.currentStreak > 0 ? '🔥' : '❄️',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${streakProvider.currentStreak}',
                    style: TextStyle(
                      color: streakProvider.reviewedToday
                          ? Catppuccin.green
                          : streakProvider.isAtRisk
                              ? Catppuccin.red
                              : Catppuccin.peach,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Center(
              child: Text(
                '(◕‿◕)',
                style: TextStyle(
                  color: Catppuccin.blue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: deckProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Catppuccin.sky))
          : decks.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- PROGRESSION CARD ---
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Catppuccin.mantle,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Catppuccin.blue, width: 4),
                          boxShadow: const [
                            BoxShadow(
                              color: Catppuccin.surface0,
                              offset: Offset(0, 8),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              r'\(^ヮ^)/',
                              style: TextStyle(
                                fontSize: 26,
                                color: Catppuccin.text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Progression',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Catppuccin.text,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        '${deckProvider.totalCardsCount}',
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          color: Catppuccin.sky,
                                        ),
                                      ),
                                      const Text('Total cartes', style: TextStyle(color: Catppuccin.subtext, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Container(width: 2, height: 36, color: Catppuccin.surface0),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        '${deckProvider.selectedDueCardsCount}',
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          color: Catppuccin.blue,
                                        ),
                                      ),
                                      const Text('À réviser', style: TextStyle(color: Catppuccin.subtext, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Container(width: 2, height: 36, color: Catppuccin.surface0),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _showStreakDialog(context, streakProvider),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              streakProvider.currentStreak > 0 ? '🔥' : '❄️',
                                              style: const TextStyle(fontSize: 20),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${streakProvider.currentStreak}',
                                              style: TextStyle(
                                                fontSize: 30,
                                                fontWeight: FontWeight.w900,
                                                color: streakProvider.reviewedToday
                                                    ? Catppuccin.green
                                                    : streakProvider.isAtRisk
                                                        ? Catppuccin.red
                                                        : Catppuccin.peach,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Série',
                                          style: TextStyle(
                                            color: streakProvider.reviewedToday
                                                ? Catppuccin.green
                                                : Catppuccin.subtext,
                                            fontSize: 11,
                                            fontWeight: streakProvider.reviewedToday ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildStreakBanner(streakProvider),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- CHIPS SÉLECTION DE PAQUETS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Paquets à réviser :',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Catppuccin.text),
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: deckProvider.selectAllDecks,
                                child: const Text('Tout', style: TextStyle(color: Catppuccin.sky, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              TextButton(
                                onPressed: deckProvider.clearSelection,
                                child: const Text('Aucun', style: TextStyle(color: Catppuccin.overlay, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: deckProvider.activeDecks.map((deck) {
                          final isSelected = deckProvider.selectedDeckIds.contains(deck.id);
                          final due = deckProvider.getDueCardsCountForDeck(deck);

                          return FilterChip(
                            label: Text(
                              '${deck.name} ($due)',
                              style: TextStyle(
                                color: isSelected ? Catppuccin.crust : Catppuccin.text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Catppuccin.sky,
                            backgroundColor: Catppuccin.mantle,
                            side: BorderSide(
                              color: isSelected ? Catppuccin.sky : Catppuccin.surface0,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            onSelected: (_) => deckProvider.toggleDeckSelection(deck.id),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // --- BOUTONS D'ACTION PRINCIPAUX ---
                      KawaiiButton(
                        height: 58,
                        onPressed: _startClassicReview,
                        child: const Text('Révision Classique 🃏', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(height: 16),
                      KawaiiButton.secondary(
                        height: 58,
                        onPressed: _startQcm,
                        child: const Text('Entraînement QCM 📝', style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('ʕ•́ᴥ•̀ʔ', style: TextStyle(fontSize: 48, color: Catppuccin.sky)),
            const SizedBox(height: 16),
            const Text(
              'Bienvenue dans Kawaii Flashcards !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Catppuccin.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aucune carte n\'est codée en dur. Crée ton premier paquet ou importe un CSV pour commencer !',
              textAlign: TextAlign.center,
              style: TextStyle(color: Catppuccin.subtext, fontSize: 14),
            ),
            const SizedBox(height: 32),
            KawaiiButton(
              onPressed: _showCreateDeckDialog,
              child: const Text('➕ Créer un premier paquet'),
            ),
            const SizedBox(height: 14),
            KawaiiButton.secondary(
              onPressed: () async {
                // Créer un paquet par défaut puis ouvrir l'import
                final provider = Provider.of<DeckProvider>(context, listen: false);
                final deck = await provider.createDeck('Général');
                if (mounted) {
                  CsvIoModal.showImportModal(context, deck);
                }
              },
              child: const Text('📥 Importer un paquet CSV'),
            ),
          ],
        ),
      ),
    );
  }
}
