import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermisosEstado {
  final bool notificaciones;
  final bool superposicion;
  final bool bateria;
  final bool lecturaPantalla;

  const PermisosEstado({
    required this.notificaciones,
    required this.superposicion,
    required this.bateria,
    required this.lecturaPantalla,
  });

  bool get todosListos =>
      notificaciones && superposicion && bateria && lecturaPantalla;
}

class PermisosService {
  static const String _prefPreparativosKey = 'preparativos_completados';
  static const MethodChannel _accessibilityChannel =
      MethodChannel('com.example.masga/accessibility');

  static bool get _esAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Consulta en el sistema operativo el estado real de los 4 permisos.
  static Future<PermisosEstado> verificarEstadoActual() async {
    if (!_esAndroid) {
      return const PermisosEstado(
        notificaciones: false,
        superposicion: false,
        bateria: false,
        lecturaPantalla: false,
      );
    }

    final notificaciones = await Permission.notification.isGranted;
    final superposicion = await Permission.systemAlertWindow.isGranted;
    final bateria = await Permission.ignoreBatteryOptimizations.isGranted;
    final lecturaPantalla = await verificarAccesibilidad();

    return PermisosEstado(
      notificaciones: notificaciones,
      superposicion: superposicion,
      bateria: bateria,
      lecturaPantalla: lecturaPantalla,
    );
  }

  /// 1. Solicita el permiso de notificaciones (Foreground Service).
  static Future<bool> solicitarNotificaciones() async {
    if (!_esAndroid) return true;
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return status.isGranted;
  }

  /// 2. Solicita el permiso de superposición sobre otras apps (System Alert Window).
  static Future<bool> solicitarSuperposicion() async {
    if (!_esAndroid) return true;
    final status = await Permission.systemAlertWindow.request();
    return status.isGranted;
  }

  /// 3. Solicita ignorar las optimizaciones de batería.
  static Future<bool> solicitarBateria() async {
    if (!_esAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// 4. Abre la configuración de Accesibilidad de Android para activar MasGa.
  static Future<void> solicitarAccesibilidad() async {
    if (!_esAndroid) return;
    try {
      await _accessibilityChannel.invokeMethod('requestAccessibilityPermission');
    } on PlatformException {
      await openAppSettings();
    }
  }

  /// Verifica si el Servicio de Accesibilidad de MasGa está activo en Android.
  static Future<bool> verificarAccesibilidad() async {
    if (!_esAndroid) return false;
    try {
      final activo = await _accessibilityChannel
          .invokeMethod<bool>('isAccessibilityPermissionEnabled');
      return activo ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Guarda en memoria local que el usuario ya completó la pantalla de preparativos.
  static Future<void> marcarPreparativosCompletados() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefPreparativosKey, true);
  }

  /// Determina si en el inicio de sesión se debe saltar directamente a PantallaPrincipal.
  /// Verifica tanto el registro en SharedPreferences como que los 4 permisos sigan activos.
  static Future<bool> debeOmitirPreparativos() async {
    final prefs = await SharedPreferences.getInstance();
    final completadoAntes = prefs.getBool(_prefPreparativosKey) ?? false;
    if (!completadoAntes) return false;

    if (!_esAndroid) return true;
    final estado = await verificarEstadoActual();
    return estado.todosListos;
  }
}
