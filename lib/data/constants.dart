import 'package:flutter/material.dart';

class KTextStyles {
  static const TextStyle titleStyle = TextStyle(
    color: Color(0xff56b3bd),
    fontFamily: 'Roboto',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );
  static const TextStyle titlesStyle = TextStyle(
    color: Color(0xff56b3bd),
    fontFamily: 'Roboto',
    fontSize: 20,
    fontWeight: FontWeight.bold,
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
    color: Color(0xff56b3bd),
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
  static final TextStyle textOnIconedButtonStyle = TextStyle();
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
}
