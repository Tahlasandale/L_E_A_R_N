import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Catppuccin {
  static const Color crust = Color(0xFF11111B); // Fond d'écran global
  static const Color base = Color(0xFF1E1E2E);  // Conteneur d'application
  static const Color mantle = Color(0xFF181825); // Fond des cartes
  static const Color surface0 = Color(0xFF313244); // Ombres 3D et bordures
  static const Color surface1 = Color(0xFF45475A);
  static const Color surface2 = Color(0xFF585B70);

  static const Color text = Color(0xFFCDD6F4);
  static const Color subtext = Color(0xFFA6ADC8);
  static const Color overlay = Color(0xFF7F849C);

  static const Color blue = Color(0xFF89B4FA); // Primaire
  static const Color sky = Color(0xFF89DCEB);  // Secondaire / Cyan
  static const Color green = Color(0xFFA6E3A1); // Succès / Facile
  static const Color peach = Color(0xFFFAB387); // Moyen / Difficile
  static const Color red = Color(0xFFF38BA8);   // Erreur / À revoir
  static const Color mauve = Color(0xFFCBA6F7); // Accent violet
  static const Color lavender = Color(0xFFB4BEFE);
  static const Color yellow = Color(0xFFF9E2AF);
  static const Color pink = Color(0xFFF5C2E7);

  static ThemeData get themeData {
    final nunitoFamily = GoogleFonts.nunito().fontFamily;

    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: nunitoFamily,
      fontFamilyFallback: const ['NotoColorEmoji', 'DroidSansFallback', 'Roboto'],
      scaffoldBackgroundColor: crust,
      primaryColor: blue,
      colorScheme: const ColorScheme.dark(
        primary: blue,
        secondary: sky,
        surface: mantle,
        error: red,
        onPrimary: crust,
        onSecondary: crust,
        onSurface: text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: crust,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: sky),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: crust,
        selectedItemColor: sky,
        unselectedItemColor: overlay,
        elevation: 8,
      ),
      useMaterial3: true,
    );
  }
}
