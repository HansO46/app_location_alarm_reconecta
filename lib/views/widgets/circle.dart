import 'package:flutter/material.dart';

class Circle extends StatefulWidget {
  const Circle({super.key});

  @override
  State<Circle> createState() => _CircleState();
}

class _CircleState extends State<Circle> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2), // Duración del ciclo
      vsync: this,
    );
    // Definir qué valores va a animar (ej: escala de 0.9 a 1.1)
    _pulseAnimation = Tween<double>(
      begin: 0.95, // Tamaño inicial
      end: 1.05, // Tamaño máximo
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut, // Suaviza el movimiento
    ));
    // Iniciar la animación (se repite infinitamente)
    _pulseController.repeat(reverse: true); // reverse hace que vuelva hacia atrás
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation, // Escucha cambios
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value, // Usa el valor actual (0.9 a 1.1)
          child: Container(
            width: 270,
            height: 270,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: Color.fromARGB(255, 81, 197, 210)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('X km to go'),
                  Text('Left'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
