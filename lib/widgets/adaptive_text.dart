import 'package:flutter/material.dart';
import '../theme/catppuccin.dart';

class AdaptiveText extends StatelessWidget {
  final String text;
  final double maxFontSize;
  final double minFontSize;
  final FontWeight fontWeight;
  final Color color;
  final TextAlign textAlign;

  const AdaptiveText(
    this.text, {
    super.key,
    this.maxFontSize = 24.0,
    this.minFontSize = 14.0,
    this.fontWeight = FontWeight.w800,
    this.color = Catppuccin.text,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: maxFontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
    );
  }
}
