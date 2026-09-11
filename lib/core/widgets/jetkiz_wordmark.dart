import 'package:flutter/material.dart';

class JetkizWordmark extends StatelessWidget {
  const JetkizWordmark({
    super.key,
    this.height = 22,
    this.semanticLabel = 'JETKIZ',
  });

  final double height;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/jetkiz_wordmark.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: semanticLabel,
    );
  }
}
