import 'package:flutter/material.dart';

class KColors {
  // Color principal de la aplicación
  static const Color mainColor = Color.fromARGB(255, 37, 142, 154);
}

class KTextStyles {
  static const TextStyle titleStyle = TextStyle(
    color: KColors.mainColor,
    fontFamily: 'Roboto',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );
  static const TextStyle titlesStyle = TextStyle(
    color: KColors.mainColor,
    fontFamily: 'Roboto',
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  );
  static const TextStyle italicSubtitleStyle = TextStyle(
    color: KColors.mainColor,
    fontFamily: 'Roboto',
    fontSize: 26,
    fontWeight: FontWeight.bold,
    fontStyle: FontStyle.italic,
    letterSpacing: 1.2,
  );
  static const TextStyle sloganStyle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    fontWeight: FontWeight.bold,
    fontStyle: FontStyle.italic,
    wordSpacing: 2,
    letterSpacing: 1.5,
  );
  static const TextStyle messageStyle = TextStyle(
    color: KColors.mainColor,
    fontFamily: 'Roboto',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );
  static const TextStyle buttonTextStyle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 22,
    fontWeight: FontWeight.bold,
    fontStyle: FontStyle.italic,
    wordSpacing: 2,
    letterSpacing: 1.5,
  );
  // Estilo con contorno (no puede ser const porque usa Paint)
  static TextStyle get textOnCircleStyle => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
        color: Colors.white,
        wordSpacing: 2,
        letterSpacing: 1.5,
      );

  static TextStyle get settingsTextStyle => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      );
  static TextStyle get alarmTextStyle => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: KColors.mainColor,
        fontFamily: 'Roboto',
        letterSpacing: 1.2,
        wordSpacing: 2,
      );
  static TextStyle get alarmDetailsTextStyle => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        wordSpacing: 1.5,
      );
}

class KButtonStyles {
  static final ButtonStyle squareButtonStyle = ButtonStyle(
    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    minimumSize: WidgetStateProperty.all<Size>(
      const Size(160, 160),
    ),
  );
}

class KConstants {
  static const String themeModeKey = 'themeModeKey';
  // API Key de Geoapify para los mapas
  // Puedes obtenerla desde: https://www.geoapify.com/get-started-with-maps-api
  static const String geoapifyApiKey =
      '73fb2772a8bc40db84dd1b1900164fdc'; // Reemplaza con tu API key real

  // Clave para guardar/cargar alarmas en SharedPreferences
  static const String alarmsKey = 'alarms';

  // Clave para guardar/cargar unidad preferida en SharedPreferences
  static const String preferredUnitKey = 'preferredUnit';

  // Clave para saber si el usuario ya vio la pantalla de bienvenida
  static const String hasSeenWelcomeKey = 'hasSeenWelcome';

  static bool get hasSeenWelcome => true;
}
