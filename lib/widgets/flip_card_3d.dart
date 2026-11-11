import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/catppuccin.dart';
import 'adaptive_text.dart';

class FlipCard3D extends StatefulWidget {
  final String frontText;
  final String backText;
  final bool isFlipped;
  final VoidCallback onFlip;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  const FlipCard3D({
    super.key,
    required this.frontText,
    required this.backText,
    required this.isFlipped,
    required this.onFlip,
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  @override
  State<FlipCard3D> createState() => _FlipCard3DState();
}

class _FlipCard3DState extends State<FlipCard3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant FlipCard3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped && !_controller.isCompleted) {
      _controller.forward();
    } else if (!widget.isFlipped && _controller.value > 0) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerFlip() {
    if (!widget.isFlipped) {
      HapticFeedback.lightImpact();
      widget.onFlip();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerFlip,
      onHorizontalDragEnd: (details) {
        final deltaX = details.velocity.pixelsPerSecond.dx;
        if (deltaX < -300) {
          // Swipe gauche
          HapticFeedback.lightImpact();
          widget.onSwipeLeft?.call();
        } else if (deltaX > 300) {
          // Swipe droite
          HapticFeedback.lightImpact();
          widget.onSwipeRight?.call();
        }
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isBack = _animation.value >= 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Effet de perspective 3D
              ..rotateY(angle),
            child: isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi), // Mirroir pour le texte du dos
                    child: _buildCardFace(
                      tag: 'RÉPONSE',
                      tagColor: Catppuccin.blue,
                      content: widget.backText,
                      borderColor: Catppuccin.blue,
                    ),
                  )
                : _buildCardFace(
                    tag: 'QUESTION',
                    tagColor: Catppuccin.sky,
                    content: widget.frontText,
                    borderColor: Catppuccin.sky,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardFace({
    required String tag,
    required Color tagColor,
    required String content,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      height: 340,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Catppuccin.mantle,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor, width: 4.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tagColor, width: 2),
            ),
            child: Text(
              tag,
              style: TextStyle(
                color: tagColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: AdaptiveText(
                content,
                maxFontSize: 28,
                minFontSize: 14,
                fontWeight: FontWeight.w900,
                color: Catppuccin.text,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!widget.isFlipped)
            const Text(
              'Appuie sur la carte pour retourner 👆',
              style: TextStyle(
                color: Catppuccin.overlay,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
