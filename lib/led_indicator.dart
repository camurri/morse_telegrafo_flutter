// lib/widgets/led_indicator.dart
import 'package:flutter/material.dart';

class LedIndicator extends StatelessWidget {
  final bool isOn;
  final Color onColor;
  final Color offColor;
  final double size;

  const LedIndicator({
    super.key,
    required this.isOn,
    this.onColor = Colors.red,
    this.offColor = const Color(0xFF424242), // cinza escuro padrão
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOn ? onColor : offColor,
        boxShadow: isOn
            ? [
          BoxShadow(
            color: onColor.withOpacity(0.6),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ]
            : [],
      ),
    );
  }
}
