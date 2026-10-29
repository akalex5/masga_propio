import 'package:shared_preferences/shared_preferences.dart';

class AdGateService {
  // Cuántos anuncios debe ver el usuario para desbloquear
  static const int anunciosRequeridos = 3;

  // Tiempo que dura desbloqueado. Para probar usa: Duration(minutes: 1)
  static const Duration duracionDesbloqueo = Duration(hours: 3);

  static const String _clave = 'ad_gate_ultima_vez';

  static Future<bool> estaDesbloqueado() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_clave);
    if (ms == null) return false;
    final ultima = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.now().difference(ultima) < duracionDesbloqueo;
  }

  static Future<void> marcarCompletado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_clave, DateTime.now().millisecondsSinceEpoch);
  }
}