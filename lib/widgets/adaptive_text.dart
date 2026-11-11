import 'package:flutter/material.dart';
import '../theme/catppuccin.dart';

class AdaptiveText extends StatelessWidget {
  final String text;
  final double maxFontSize;
  final double minFontSize;
  final FontWeight fontWeight;
  final Color color;
  final TextAlign textAlign;
  final int? maxLines;

  const AdaptiveText(
    this.text, {
    super.key,
    this.maxFontSize = 24.0,
    this.minFontSize = 14.0,
    this.fontWeight = FontWeight.w800,
    this.color = Catppuccin.text,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (maxLines == 1) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text(
              text,
              maxLines: maxLines,
              softWrap: true,
              textAlign: textAlign,
              style: TextStyle(
                fontSize: maxFontSize,
                fontWeight: fontWeight,
                color: color,
                height: 1.3,
              ),
            ),
          ),
        );
      },
    );
  }
}
