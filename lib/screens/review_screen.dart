import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/deck_provider.dart';
import '../providers/review_provider.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';
import '../theme/catppuccin.dart';
import '../widgets/flip_card_3d.dart';
import '../widgets/kawaii_button.dart';

class ReviewScreen extends StatelessWidget {
  final bool isIntensiveMinutes;

  const ReviewScreen({
    super.key,
    required this.isIntensiveMinutes,
  });

  void _rate(BuildContext context, int rating) {
    HapticFeedback.lightImpact();
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
    final storage = Provider.of<StorageService>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    reviewProvider.rateCurrentCard(
      rating: rating,
      isIntensiveMinutes: isIntensiveMinutes,
      desiredRetention: settingsProvider.desiredRetention,
      storage: storage,
    );

    if (reviewProvider.isSessionFinished) {
      _showCompletionDialog(context);
    }
  }

  void _showCompletionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Catppuccin.mantle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Center(
          child: Text(
            r'🎉 \(^ヮ^)/ 🎉',
            style: TextStyle(fontSize: 28, color: Catppuccin.green, fontWeight: FontWeight.bold),
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Session terminée !',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Catppuccin.text),
            ),
            SizedBox(height: 8),
            Text(
              'Super travail ! Toutes les cartes de cette session ont été révisées.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Catppuccin.subtext, fontSize: 14),
            ),
          ],
        ),
        actions: [
          KawaiiButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              // Recharger les compteurs du dashboard
              Provider.of<DeckProvider>(context, listen: false).loadDecks();
            },
            child: const Text('Retour à l\'accueil 🚀'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviewProvider = Provider.of<ReviewProvider>(context);
    final card = reviewProvider.currentCard;

    if (card == null || reviewProvider.isSessionFinished) {
      return Scaffold(
        appBar: AppBar(title: const Text('Révision')),
        body: Center(
          child: KawaiiButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour à l\'accueil'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Carte ${reviewProvider.progressNumber} / ${reviewProvider.totalInSession}',
          style: const TextStyle(
            color: Catppuccin.sky,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: reviewProvider.isRandomOrder ? Catppuccin.mauve : Catppuccin.overlay,
            ),
            tooltip: reviewProvider.isRandomOrder ? 'Ordre aléatoire actif' : 'Activer l\'ordre aléatoire',
            onPressed: () {
              HapticFeedback.lightImpact();
              reviewProvider.toggleRandomOrder();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Catppuccin.mantle,
                  duration: const Duration(milliseconds: 900),
                  content: Text(
                    reviewProvider.isRandomOrder
                        ? '🔀 Mode Aléatoire ACTIVÉ !'
                        : '⏱️ Tri FSRS rétabli !',
                    style: TextStyle(
                      color: reviewProvider.isRandomOrder ? Catppuccin.mauve : Catppuccin.sky,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.0),
            child: Center(
              child: Text(
                "(ง'̀-'́)ง",
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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!reviewProvider.isFlipped) {
            HapticFeedback.lightImpact();
            reviewProvider.flipCard();
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: FlipCard3D(
                    frontText: card.front,
                    backText: card.back,
                    isFlipped: reviewProvider.isFlipped,
                    onFlip: reviewProvider.flipCard,
                    onSwipeLeft: reviewProvider.isFlipped ? () => _rate(context, 1) : null,
                    onSwipeRight: reviewProvider.isFlipped ? () => _rate(context, 3) : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // --- NOTATION CONTROLS ---
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: reviewProvider.isFlipped ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !reviewProvider.isFlipped,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    child: Row(
                      children: [
                        _buildRatingButton(
                          context: context,
                          label: 'À revoir',
                          emoji: '😭',
                          rating: 1,
                          color: Catppuccin.red,
                        ),
                        const SizedBox(width: 8),
                        _buildRatingButton(
                          context: context,
                          label: 'Difficile',
                          emoji: '🤔',
                          rating: 2,
                          color: Catppuccin.peach,
                        ),
                        const SizedBox(width: 8),
                        _buildRatingButton(
                          context: context,
                          label: 'Bien',
                          emoji: '😊',
                          rating: 3,
                          color: Catppuccin.green,
                        ),
                        const SizedBox(width: 8),
                        _buildRatingButton(
                          context: context,
                          label: 'Facile',
                          emoji: '🤩',
                          rating: 4,
                          color: Catppuccin.blue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingButton({
    required BuildContext context,
    required String label,
    required String emoji,
    required int rating,
    required Color color,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _rate(context, rating),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
