import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/catppuccin.dart';

class KawaiiButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color shadowColor;
  final Color textColor;
  final double height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const KawaiiButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor = Catppuccin.blue,
    this.shadowColor = Catppuccin.surface0,
    this.textColor = Catppuccin.crust,
    this.height = 54.0,
    this.width,
    this.borderRadius = 22.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
  });

  const KawaiiButton.secondary({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor = Catppuccin.sky,
    this.shadowColor = Catppuccin.surface0,
    this.textColor = Catppuccin.crust,
    this.height = 54.0,
    this.width,
    this.borderRadius = 22.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
  });

  @override
  State<KawaiiButton> createState() => _KawaiiButtonState();
}

class _KawaiiButtonState extends State<KawaiiButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final shadowHeight = _isPressed ? 0.0 : 5.0;
    final translateY = _isPressed ? 5.0 : 0.0;

    return GestureDetector(
      onTapDown: isEnabled ? _onTapDown : null,
      onTapUp: isEnabled ? _onTapUp : null,
      onTapCancel: isEnabled ? _onTapCancel : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: widget.width,
        height: widget.height,
        transform: Matrix4.translationValues(0, translateY, 0),
        decoration: BoxDecoration(
          color: isEnabled ? widget.backgroundColor : widget.backgroundColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.shadowColor,
            width: 3.5,
          ),
          boxShadow: [
            if (shadowHeight > 0)
              BoxShadow(
                color: widget.shadowColor,
                offset: Offset(0, shadowHeight),
                blurRadius: 0,
              ),
          ],
        ),
        padding: widget.padding,
        child: Center(
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontFamily: 'Nunito',
              fontFamilyFallback: const ['NotoColorEmoji', 'DroidSansFallback', 'Roboto'],
              color: widget.textColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
