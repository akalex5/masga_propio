import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResultadoOperacion {
  final bool exito;
  final String mensaje;

  const ResultadoOperacion({
    required this.exito,
    required this.mensaje,
  });
}

class SupabaseService extends ChangeNotifier {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  static const String supabaseUrl = 'https://ixgmfuxkgkgiihapelbz.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_SMYgBt2apFLKidQEcxV35g_PdtSWBb1';

  static const int maxLlaves = 9;
  static const int costoDesbloqueoLlaves = 3;

  static const String _prefLlaves = 'cache_balance_llaves';
  static const String _prefFinTurno = 'cache_fin_acceso_ms';

  int _balanceLlaves = 0;
  DateTime? _finAccesoTemporal;
  bool _cargandoEstado = false;

  SupabaseClient get client => Supabase.instance.client;

  User? get usuarioActual => client.auth.currentUser;
  bool get tieneSesionActiva => client.auth.currentSession != null;

  String get nombreConductor {
    final user = usuarioActual;
    if (user == null) return 'Conductor';
    final metaNombre = user.userMetadata?['nombre'] as String? ??
        user.userMetadata?['full_name'] as String?;
    if (metaNombre != null && metaNombre.trim().isNotEmpty) {
      return metaNombre.trim();
    }
    final email = user.email ?? '';
    if (email.contains('@')) {
      return email.split('@').first;
    }
    return 'Conductor';
  }

  String get emailConductor => usuarioActual?.email ?? '';

  int get balanceLlaves => _balanceLlaves.clamp(0, maxLlaves);
  DateTime? get finAccesoTemporal => _finAccesoTemporal;
  bool get cargandoEstado => _cargandoEstado;

  /// Retorna true si la fecha actual es MENOR a fin_acceso_temporal (ESTADO 2: APP ACTIVA)
  bool get turnoActivo {
    if (_finAccesoTemporal == null) return false;
    return DateTime.now().isBefore(_finAccesoTemporal!);
  }

  /// Tiempo restante del turno de 4 horas
  Duration get tiempoRestante {
    if (!turnoActivo || _finAccesoTemporal == null) return Duration.zero;
    final diff = _finAccesoTemporal!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Formato "03:45 hrs" o "00:12 min"
  String get textoTiempoRestante {
    final restante = tiempoRestante;
    if (restante == Duration.zero) return '00:00 hrs';
    final horas = restante.inHours.toString().padLeft(2, '0');
    final minutos = (restante.inMinutes % 60).toString().padLeft(2, '0');
    return '$horas:$minutos hrs';
  }

  Future<void> inicializar() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    // Cargar caché local inicial para evitar parpadeos
    await _cargarCacheLocal();

    // Escuchar cambios de sesión de Auth
    client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        cargarEstadoConductor();
      } else {
        _balanceLlaves = 0;
        _finAccesoTemporal = null;
        _notificar();
      }
    });

    if (tieneSesionActiva) {
      await cargarEstadoConductor();
    }
  }

  void _notificar() {
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks ||
        binding.schedulerPhase == SchedulerPhase.midFrameMicrotasks) {
      binding.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  Future<void> _cargarCacheLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _balanceLlaves = (prefs.getInt(_prefLlaves) ?? 0).clamp(0, maxLlaves);
    final ms = prefs.getInt(_prefFinTurno);
    if (ms != null) {
      _finAccesoTemporal = DateTime.fromMillisecondsSinceEpoch(ms);
    }
    _notificar();
  }

  Future<void> _guardarCacheLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLlaves, _balanceLlaves);
    if (_finAccesoTemporal != null) {
      await prefs.setInt(
          _prefFinTurno, _finAccesoTemporal!.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_prefFinTurno);
    }
  }

  // ==========================================
  // AUTENTICACIÓN (Correo / Google)
  // ==========================================

  Future<ResultadoOperacion> iniciarSesionConCorreo({
    required String email,
    required String password,
  }) async {
    try {
      final res = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.user != null) {
        await cargarEstadoConductor();
        return const ResultadoOperacion(
          exito: true,
          mensaje: '¡Bienvenido de nuevo!',
        );
      }
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'No se pudo iniciar sesión. Verifica tus datos.',
      );
    } on AuthException catch (e) {
      return ResultadoOperacion(
        exito: false,
        mensaje: _traducirErrorAuth(e.message),
      );
    } catch (_) {
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'Revisa tu conexión a internet e inténtalo de nuevo.',
      );
    }
  }

  Future<ResultadoOperacion> registrarConCorreo({
    required String email,
    required String password,
    String? nombre,
  }) async {
    try {
      final res = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          if (nombre != null && nombre.trim().isNotEmpty)
            'nombre': nombre.trim(),
        },
      );

      if (res.session != null) {
        await cargarEstadoConductor();
        return const ResultadoOperacion(
          exito: true,
          mensaje: '¡Cuenta creada con éxito!',
        );
      } else if (res.user != null) {
        // Si en Supabase está activada la confirmación por correo
        return const ResultadoOperacion(
          exito: true,
          mensaje:
              '¡Cuenta creada! Revisa tu correo para confirmar o inicia sesión.',
        );
      }
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'No se pudo completar el registro.',
      );
    } on AuthException catch (e) {
      return ResultadoOperacion(
        exito: false,
        mensaje: _traducirErrorAuth(e.message),
      );
    } catch (_) {
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'Revisa tu conexión a internet para registrarte.',
      );
    }
  }

  Future<ResultadoOperacion> iniciarSesionConGoogle() async {
    try {
      final lanzado = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.masga://login-callback/',
      );
      if (lanzado) {
        return const ResultadoOperacion(
          exito: true,
          mensaje: 'Completando acceso con Google...',
        );
      }
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'No se pudo abrir el inicio de sesión con Google.',
      );
    } on AuthException catch (e) {
      return ResultadoOperacion(
        exito: false,
        mensaje: _traducirErrorAuth(e.message),
      );
    } catch (_) {
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'Revisa tu conexión a internet.',
      );
    }
  }

  Future<ResultadoOperacion> recuperarContrasena(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email.trim());
      return const ResultadoOperacion(
        exito: true,
        mensaje: 'Se envió un enlace de recuperación a tu correo.',
      );
    } on AuthException catch (e) {
      return ResultadoOperacion(
        exito: false,
        mensaje: _traducirErrorAuth(e.message),
      );
    } catch (_) {
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'Revisa tu conexión a internet.',
      );
    }
  }

  Future<void> cerrarSesion() async {
    try {
      await client.auth.signOut();
    } catch (_) {}
    _balanceLlaves = 0;
    _finAccesoTemporal = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefLlaves);
    await prefs.remove(_prefFinTurno);
    _notificar();
  }

  // ==========================================
  // BILLETERA DE LLAVES Y TURNO DE 4 HORAS (RPC)
  // ==========================================

  Future<void> cargarEstadoConductor() async {
    if (!tieneSesionActiva) return;
    _cargandoEstado = true;

    try {
      final respuesta = await client.rpc('obtener_estado_conductor');
      if (respuesta is Map) {
        if (respuesta['balance_llaves'] != null) {
          _balanceLlaves =
              ((respuesta['balance_llaves'] as num).toInt()).clamp(0, maxLlaves);
        }
        final finStr = respuesta['fin_acceso_temporal'] as String?;
        if (finStr != null && finStr.isNotEmpty) {
          _finAccesoTemporal = DateTime.tryParse(finStr)?.toLocal();
        } else {
          _finAccesoTemporal = null;
        }
        await _guardarCacheLocal();
      }
    } catch (e) {
      debugPrint('Error al consultar estado en Supabase: $e');
    } finally {
      _cargandoEstado = false;
      _notificar();
    }
  }

  /// Consume 3 llaves en el servidor de Supabase y suma 4 horas a fin_acceso_temporal
  Future<ResultadoOperacion> desbloquearTurno4Horas() async {
    if (!tieneSesionActiva) {
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'Inicia sesión para desbloquear tu turno.',
      );
    }

    try {
      final respuesta = await client.rpc('desbloquear_turno_4h');
      if (respuesta is Map) {
        final exito = respuesta['exito'] == true;
        if (exito) {
          _balanceLlaves = ((respuesta['balance_llaves'] as num?)?.toInt() ??
                  (_balanceLlaves - costoDesbloqueoLlaves))
              .clamp(0, maxLlaves);
          final finStr = respuesta['fin_acceso_temporal'] as String?;
          if (finStr != null) {
            _finAccesoTemporal = DateTime.tryParse(finStr)?.toLocal();
          } else {
            _finAccesoTemporal = DateTime.now().add(const Duration(hours: 4));
          }
          await _guardarCacheLocal();
          _notificar();
          return const ResultadoOperacion(
            exito: true,
            mensaje: '¡Turno desbloqueado por 4 horas! (-3 🔑)',
          );
        } else {
          final msg = (respuesta['mensaje'] as String?) ??
              'No tienes suficientes llaves (necesitas 3).';
          return ResultadoOperacion(exito: false, mensaje: msg);
        }
      }
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'Respuesta inesperada del servidor.',
      );
    } catch (e) {
      debugPrint('Error RPC desbloquear_turno_4h: $e');
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'Revisa tu conexión a internet para desbloquear el turno.',
      );
    }
  }

  /// Suma 1 llave en Supabase tras completar un anuncio de recompensa de AdMob
  Future<ResultadoOperacion> sumarLlavePorAnuncio() async {
    if (!tieneSesionActiva) {
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'Inicia sesión para guardar tus llaves.',
      );
    }

    try {
      final respuesta = await client.rpc('sumar_llave_por_anuncio');
      if (respuesta is Map) {
        final exito = respuesta['exito'] == true;
        if (exito) {
          _balanceLlaves = ((respuesta['balance_llaves'] as num?)?.toInt() ??
                  (_balanceLlaves + 1))
              .clamp(0, maxLlaves);
          await _guardarCacheLocal();
          _notificar();
          return ResultadoOperacion(
            exito: true,
            mensaje: '¡Ganaste +1 llave! (🔑 $_balanceLlaves/$maxLlaves)',
          );
        } else {
          final msg = (respuesta['mensaje'] as String?) ??
              'Billetera llena (9/9).';
          return ResultadoOperacion(exito: false, mensaje: msg);
        }
      }
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'No se pudo acreditar la llave.',
      );
    } catch (e) {
      debugPrint('Error RPC sumar_llave_por_anuncio: $e');
      return const ResultadoOperacion(
        exito: false,
        mensaje: 'Revisa tu conexión a internet para acreditar tu llave.',
      );
    }
  }

  String _traducirErrorAuth(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (lower.contains('user already registered')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Confirma tu correo electrónico antes de iniciar sesión (o desactiva Confirm Email en Supabase Auth).';
    }
    if (lower.contains('password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return msg;
  }
}
