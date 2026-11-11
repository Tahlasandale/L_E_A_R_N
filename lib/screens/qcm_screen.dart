import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../providers/review_provider.dart';
import '../services/storage_service.dart';
import '../theme/catppuccin.dart';
import '../widgets/adaptive_text.dart';
import '../widgets/kawaii_button.dart';

class QcmScreen extends StatefulWidget {
  final List<Flashcard> poolCards;
  final bool isIntensiveMinutes;

  const QcmScreen({
    super.key,
    required this.poolCards,
    required this.isIntensiveMinutes,
  });

  @override
  State<QcmScreen> createState() => _QcmScreenState();
}

class _QcmScreenState extends State<QcmScreen> {
  List<String> _currentChoices = [];
  String? _selectedAnswer;
  String? _correctAnswer;
  bool _isAnswered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChoicesForCurrentCard();
    });
  }

  void _loadChoicesForCurrentCard() {
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
    final card = reviewProvider.currentCard;

    if (card != null) {
      final choices = reviewProvider.generateQcmChoices(
        currentCard: card,
        allPoolCards: widget.poolCards,
      );
      setState(() {
        _currentChoices = choices;
        _correctAnswer = card.back.trim();
        _selectedAnswer = null;
        _isAnswered = false;
      });
    }
  }

  void _handleAnswer(String answer) {
    if (_isAnswered) return;
    HapticFeedback.lightImpact();

    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
    final storage = Provider.of<StorageService>(context, listen: false);
    final card = reviewProvider.currentCard;
    if (card == null) return;

    setState(() {
      _selectedAnswer = answer;
      _isAnswered = true;
    });

    final isCorrect = answer.trim() == _correctAnswer;
    reviewProvider.rateCurrentCard(
      rating: isCorrect ? 4 : 1,
      isIntensiveMinutes: widget.isIntensiveMinutes,
      storage: storage,
    );

    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (reviewProvider.isSessionFinished) {
        _showCompletionDialog();
      } else {
        _loadChoicesForCurrentCard();
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Catppuccin.mantle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Center(
          child: Text(
            r'🎉 (*^‿^*) 🎉',
            style: TextStyle(fontSize: 28, color: Catppuccin.green, fontWeight: FontWeight.bold),
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Colle terminée !',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Catppuccin.text),
            ),
            SizedBox(height: 8),
            Text(
              'Excellente session de colles QCM !',
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
        appBar: AppBar(title: const Text('Mode Colles (QCM)')),
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
          'Colle ${reviewProvider.progressNumber} / ${reviewProvider.totalInSession}',
          style: const TextStyle(
            color: Catppuccin.sky,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- QUESTION BOX ---
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Catppuccin.mantle,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Catppuccin.blue, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        offset: Offset(0, 8),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Center(
                    child: AdaptiveText(
                      card.front,
                      maxFontSize: 26,
                      minFontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Catppuccin.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- 2x2 GRID OF CHOICES ---
              Expanded(
                flex: 5,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: _currentChoices.length,
                  itemBuilder: (context, index) {
                    final choice = _currentChoices[index];
                    return _buildQcmChoiceButton(choice);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQcmChoiceButton(String choice) {
    Color bg = Catppuccin.mantle;
    Color border = Catppuccin.surface0;
    Color textCol = Catppuccin.text;

    if (_isAnswered) {
      if (choice == _correctAnswer) {
        bg = Catppuccin.green;
        border = const Color(0xFF40A02B);
        textCol = Catppuccin.crust;
      } else if (choice == _selectedAnswer) {
        bg = Catppuccin.red;
        border = const Color(0xFFD20F39);
        textCol = Catppuccin.crust;
      }
    }

    return GestureDetector(
      onTap: _isAnswered ? null : () => _handleAnswer(choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: border.withValues(alpha: 0.5),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            choice,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textCol,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
