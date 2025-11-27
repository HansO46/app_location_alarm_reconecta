import 'package:flutter/material.dart';

class SwipeDown extends StatelessWidget {
  final VoidCallback? onSwipeDown;

  const SwipeDown({super.key, this.onSwipeDown});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSwipeDown,
      child: Column(
        children: [
          // Líneas de swipe elegantes

          const SizedBox(height: 4),
          // Flecha hacia abajo (solo indicador visual, sin animación)
          Icon(Icons.keyboard_arrow_down, size: 24, color: Colors.black),
        ],
      ),
    );
  }
}
