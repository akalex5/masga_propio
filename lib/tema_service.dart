import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TemaService extends ChangeNotifier {
  TemaService._();
  static final TemaService instance = TemaService._();

  static const String _keyThemeMode = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool get esOscuro {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    // Si es sistema, se resuelve con el brillo de la plataforma
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  Future<void> inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final modoGuardado = prefs.getString(_keyThemeMode);
    if (modoGuardado != null) {
      switch (modoGuardado) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          _themeMode = ThemeMode.system;
          break;
      }
    }
    notifyListeners();
  }

  Future<void> cambiarModo(ThemeMode nuevoModo) async {
    if (_themeMode == nuevoModo) return;
    _themeMode = nuevoModo;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String valor;
    switch (nuevoModo) {
      case ThemeMode.light:
        valor = 'light';
        break;
      case ThemeMode.dark:
        valor = 'dark';
        break;
      case ThemeMode.system:
        valor = 'system';
        break;
    }
    await prefs.setString(_keyThemeMode, valor);
  }

  // ==========================================
  // PALETA DE COLORES SEMÁNTICOS (MasGa Design)
  // ==========================================

  // Modo Oscuro (Proton / Deep Tech)
  static const Color darkBg = Color(0xFF0D1117);
  static const Color darkCard = Color(0xFF161B22);
  static const Color darkBorder = Color(0xFF30363D);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFF8B949E);

  // Modo Claro (mismo lenguaje visual pero fondo limpio)
  static const Color lightBg = Color(0xFFF3F4F6); // Gris claro suave
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0); // Borde sutil nítido
  static const Color lightTextPrimary = Color(0xFF0F172A); // Azul carbón profundo
  static const Color lightTextSecondary = Color(0xFF64748B); // Gris pizarra

  // Acentos comunes (identidad visual MasGa)
  static const Color accentGreen = Color(0xFF10B981); // Esmeralda / Conviene
  static const Color accentCyan = Color(0xFF0EA5E9);  // Cian espacial
  static const Color accentAmber = Color(0xFFF59E0B); // Ámbar / Alerta
  static const Color accentRed = Color(0xFFEF4444);   // Rojo / No conviene

  // Temas ThemeData oficiales de Flutter
  static ThemeData get temaClaro {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: accentGreen,
      scaffoldBackgroundColor: lightBg,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.light(
        primary: accentGreen,
        secondary: accentCyan,
        surface: lightCard,
        error: accentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
      ),
    );
  }

  static ThemeData get temaOscuro {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: accentGreen,
      scaffoldBackgroundColor: darkBg,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: accentGreen,
        secondary: accentCyan,
        surface: darkCard,
        error: accentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),
    );
  }
}
