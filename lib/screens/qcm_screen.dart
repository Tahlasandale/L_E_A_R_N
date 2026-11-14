import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../providers/review_provider.dart';
import '../providers/settings_provider.dart';
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
  bool _showBigCorrectAnswer = false;
  String? _zoomedChoice;

  Timer? _phase1Timer;
  Timer? _phase2Timer;
  VoidCallback? _pendingRateCallback;

  // Suivi du score pour l'écran de fin
  int _correctCount = 0;
  int _totalAnswered = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChoicesForCurrentCard();
    });
  }

  @override
  void dispose() {
    _phase1Timer?.cancel();
    _phase2Timer?.cancel();
    _pendingRateCallback?.call();
    _pendingRateCallback = null;
    super.dispose();
  }

  void _loadChoicesForCurrentCard() {
    _phase1Timer?.cancel();
    _phase2Timer?.cancel();
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
        _showBigCorrectAnswer = false;
        _zoomedChoice = null;
      });
    }
  }

  void _handleAnswer(String answer) {
    if (_isAnswered) return;
    HapticFeedback.lightImpact();

    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
    final storage = Provider.of<StorageService>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final card = reviewProvider.currentCard;
    if (card == null) return;

    final isCorrect = answer.trim() == _correctAnswer;
    setState(() {
      _selectedAnswer = answer;
      _isAnswered = true;
      _totalAnswered++;
      if (isCorrect) _correctCount++;
    });

    // Enregistrer l'action de notation pour l'exécuter à la fin de la transition
    final rating = isCorrect ? 4 : 1;
    final desiredRetention = settingsProvider.desiredRetention;
    _pendingRateCallback = () {
      reviewProvider.rateCurrentCard(
        rating: rating,
        isIntensiveMinutes: widget.isIntensiveMinutes,
        desiredRetention: desiredRetention,
        storage: storage,
      );
    };

    // Phase 1 : Affichage immédiat du feedback vert/rouge sur les boutons (450ms)
    _phase1Timer?.cancel();
    _phase1Timer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _showBigCorrectAnswer = true;
      });

      // Phase 2 : Affichage de la bonne réponse en grand pour la durée configurée
      final durationMs = (settingsProvider.qcmGoodAnswerDuration * 1000).round();
      _phase2Timer?.cancel();
      _phase2Timer = Timer(Duration(milliseconds: durationMs), () {
        if (!mounted) return;
        // Appliquer la notation maintenant : la carte avance et notifie la nouvelle carte
        _pendingRateCallback?.call();
        _pendingRateCallback = null;

        if (!reviewProvider.isSessionFinished) {
          _loadChoicesForCurrentCard();
        } else {
          setState(() {
            _showBigCorrectAnswer = false;
          });
        }
      });
    });
  }

  void _restartColle() {
    _phase1Timer?.cancel();
    _phase2Timer?.cancel();
    _pendingRateCallback = null;
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
    setState(() {
      _correctCount = 0;
      _totalAnswered = 0;
      _isAnswered = false;
      _selectedAnswer = null;
      _showBigCorrectAnswer = false;
      _zoomedChoice = null;
    });
    reviewProvider.initSession(cards: widget.poolCards);
    _loadChoicesForCurrentCard();
  }

  @override
  Widget build(BuildContext context) {
    final reviewProvider = Provider.of<ReviewProvider>(context);
    final card = reviewProvider.currentCard;

    // --- ÉCRAN DE FIN INTÉGRÉ ---
    if (card == null || reviewProvider.isSessionFinished) {
      return _buildCompletionScreen(context, reviewProvider);
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- QUESTION BOX AVEC ANIMATION DE TRANSITION ---
              Expanded(
                flex: 4,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.08, 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Container(
                    key: ValueKey('question_${card.id}'),
                    padding: const EdgeInsets.all(22),
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
                        minFontSize: 14,
                        maxLines: 4, // Permet les retours à la ligne pour questions longues
                        fontWeight: FontWeight.w900,
                        color: Catppuccin.text,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- ZONE DES RÉPONSES AVEC GESTION DU ZOOM LONG-PRESS ---
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    // Bascule fluide entre les 4 lignes de choix et la grande bonne réponse
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.08, 0.0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                          child: FadeTransition(opacity: animation, child: child),
                        );
                      },
                      child: _showBigCorrectAnswer
                          ? _buildBigCorrectAnswerBox()
                          : _buildChoicesColumn(card.id),
                    ),

                    // Overlay de Zoom au maintien long
                    if (_zoomedChoice != null)
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Catppuccin.mantle,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Catppuccin.mauve, width: 4.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 8),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.zoom_in, color: Catppuccin.mauve, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Aperçu agrandi',
                                    style: TextStyle(
                                      color: Catppuccin.mauve,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Center(
                                  child: AdaptiveText(
                                    _zoomedChoice!,
                                    maxFontSize: 28,
                                    minFontSize: 16,
                                    maxLines: 5,
                                    fontWeight: FontWeight.w900,
                                    color: Catppuccin.text,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Relâche pour revenir à la liste 👆',
                                style: TextStyle(color: Catppuccin.overlay, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoicesColumn(int cardId) {
    return Column(
      key: ValueKey('choices_$cardId'),
      children: [
        for (int i = 0; i < _currentChoices.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Expanded(
            child: _buildQcmChoiceButton(_currentChoices[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildBigCorrectAnswerBox() {
    final isCorrect = _selectedAnswer?.trim() == _correctAnswer;
    final accentColor = isCorrect ? Catppuccin.green : Catppuccin.peach;

    return Container(
      key: const ValueKey('big_correct_answer'),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Catppuccin.mantle,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accentColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.25),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.lightbulb_outline_rounded,
                color: accentColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'EXCELLENT ! 🎉' : 'BONNE RÉPONSE : 💡',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: AdaptiveText(
                _correctAnswer ?? '',
                maxFontSize: 28,
                minFontSize: 15,
                maxLines: 5,
                fontWeight: FontWeight.w900,
                color: Catppuccin.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQcmChoiceButton(String choice) {
    Color bg = Catppuccin.mantle;
    Color border = Catppuccin.surface0;
    Color textCol = Catppuccin.text;

    if (_isAnswered) {
      if (choice.trim() == _correctAnswer) {
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
      onLongPressStart: (_) {
        HapticFeedback.mediumImpact();
        setState(() => _zoomedChoice = choice);
      },
      onLongPressEnd: (_) {
        setState(() => _zoomedChoice = null);
      },
      onLongPressCancel: () {
        setState(() => _zoomedChoice = null);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 3),
          boxShadow: [
            BoxShadow(
              color: border.withValues(alpha: 0.35),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: AdaptiveText(
            choice,
            maxFontSize: 18,
            minFontSize: 12,
            maxLines: 2,
            fontWeight: FontWeight.w800,
            color: textCol,
          ),
        ),
      ),
    );
  }

  /// Écran de fin de session Colles intégré (sans AlertDialog)
  Widget _buildCompletionScreen(BuildContext context, ReviewProvider reviewProvider) {
    final int scorePercent = _totalAnswered > 0
        ? ((_correctCount / _totalAnswered) * 100).round()
        : 100;

    String encouragement;
    Color scoreColor;

    if (scorePercent >= 90) {
      encouragement = '🤩 Parfait ! Tu maîtrises tes colles comme un chef !';
      scoreColor = Catppuccin.green;
    } else if (scorePercent >= 70) {
      encouragement = '👏 Très bon travail ! Tu es bien affûté !';
      scoreColor = Catppuccin.sky;
    } else if (scorePercent >= 50) {
      encouragement = '😊 Pas mal du tout ! Encore un petit effort.';
      scoreColor = Catppuccin.yellow;
    } else {
      encouragement = '💪 Ne baisse pas les bras, refais un tour de colle !';
      scoreColor = Catppuccin.peach;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Colle Terminée ! 🎯',
          style: TextStyle(fontWeight: FontWeight.w900, color: Catppuccin.sky),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '🎉 (*^‿^*) 🎉',
                style: TextStyle(fontSize: 48, color: Catppuccin.green, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Carte de récapitulation du score
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Catppuccin.mantle,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Catppuccin.blue, width: 3.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      offset: Offset(0, 8),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Score de la Session',
                      style: TextStyle(
                        color: Catppuccin.subtext,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_correctCount / $_totalAnswered',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: scoreColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$scorePercent% de réussite',
                      style: const TextStyle(
                        color: Catppuccin.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      encouragement,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Catppuccin.lavender,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Boutons d'action
              KawaiiButton.secondary(
                height: 52,
                onPressed: _restartColle,
                child: const Text('Recommencer la colle 🔄'),
              ),
              const SizedBox(height: 14),
              KawaiiButton(
                height: 52,
                onPressed: () {
                  Navigator.pop(context);
                  Provider.of<DeckProvider>(context, listen: false).loadDecks();
                },
                child: const Text('Retour à l\'accueil 🏠'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
