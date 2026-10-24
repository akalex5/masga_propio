import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViajeRegistrado {
  final String plataforma;
  final String hora;
  final double tarifaBruta;
  final double distanciaKm;
  final double costoGasolina;
  final double costoImpuestos;
  final double costoDepreciacion;
  final double gananciaNeta;
  final double gananciaPorKmNeto;
  final bool conviene;

  const ViajeRegistrado({
    required this.plataforma,
    required this.hora,
    required this.tarifaBruta,
    required this.distanciaKm,
    required this.costoGasolina,
    required this.costoImpuestos,
    required this.costoDepreciacion,
    required this.gananciaNeta,
    required this.gananciaPorKmNeto,
    required this.conviene,
  });

  double get costoTotal => costoGasolina + costoImpuestos + costoDepreciacion;

  Map<String, dynamic> toJson() => {
        'plataforma': plataforma,
        'hora': hora,
        'tarifaBruta': tarifaBruta,
        'distanciaKm': distanciaKm,
        'costoGasolina': costoGasolina,
        'costoImpuestos': costoImpuestos,
        'costoDepreciacion': costoDepreciacion,
        'gananciaNeta': gananciaNeta,
        'gananciaPorKmNeto': gananciaPorKmNeto,
        'conviene': conviene,
      };

  factory ViajeRegistrado.fromMap(Map<dynamic, dynamic> map) {
    return ViajeRegistrado(
      plataforma: (map['plataforma'] as String?) ?? 'Uber Driver',
      hora: (map['hora'] as String?) ?? 'Hoy',
      tarifaBruta: (map['tarifaBruta'] as num?)?.toDouble() ?? 0.0,
      distanciaKm: (map['distanciaKm'] as num?)?.toDouble() ?? 0.0,
      costoGasolina: (map['costoGasolina'] as num?)?.toDouble() ?? 0.0,
      costoImpuestos: (map['costoImpuestos'] as num?)?.toDouble() ?? 0.0,
      costoDepreciacion: (map['costoDepreciacion'] as num?)?.toDouble() ?? 0.0,
      gananciaNeta: (map['gananciaNeta'] as num?)?.toDouble() ?? 0.0,
      gananciaPorKmNeto: (map['gananciaPorKmNeto'] as num?)?.toDouble() ?? 0.0,
      conviene: (map['conviene'] as bool?) ?? true,
    );
  }
}

class ViajesService extends ChangeNotifier {
  ViajesService._() {
    _configurarCanalNativo();
  }

  static final ViajesService instance = ViajesService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.masga/accessibility');

  static const String _keyGananciaPorKm = 'costo_ganancia_por_km';
  static const String _keyGastoCombustible = 'costo_gasto_combustible';
  static const String _keyPrecioCombustible = 'costo_precio_combustible';
  static const String _keyTasaImpuestos = 'costo_tasa_impuestos';
  static const String _keyDepreciacionPorKm = 'costo_depreciacion_por_km';
  static const String _keyViajesGuardados = 'viajes_registrados_json';

  bool _inicializado = false;
  bool _monitoreando = false;
  int _indiceSimulacion = 0;

  double _gananciaPorKm = 10.00;
  double _gastoCombustible = 14.0;
  double _precioCombustible = 24.00;
  double _tasaImpuestos = 8.0;
  double _depreciacionPorKm = 2.50;

  final List<ViajeRegistrado> _viajesHoy = [];

  bool get monitoreando => _monitoreando;
  double get gananciaPorKm => _gananciaPorKm;
  double get gastoCombustible => _gastoCombustible;
  double get precioCombustible => _precioCombustible;
  double get tasaImpuestos => _tasaImpuestos;
  double get depreciacionPorKm => _depreciacionPorKm;

  List<ViajeRegistrado> get viajesHoy => List.unmodifiable(_viajesHoy);

  double get gananciaDeHoy =>
      _viajesHoy.fold(0.0, (acc, item) => acc + item.gananciaNeta);

  bool get _esAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _configurarCanalNativo() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTripRegistered' && call.arguments is Map) {
        final mapa = call.arguments as Map<dynamic, dynamic>;
        final nuevoViaje = ViajeRegistrado.fromMap(mapa);
        await agregarViaje(nuevoViaje);
      }
    });
  }

  Future<void> inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    _gananciaPorKm = prefs.getDouble(_keyGananciaPorKm) ?? 10.00;
    _gastoCombustible = prefs.getDouble(_keyGastoCombustible) ?? 14.0;
    _precioCombustible = prefs.getDouble(_keyPrecioCombustible) ?? 24.00;
    _tasaImpuestos = prefs.getDouble(_keyTasaImpuestos) ?? 8.0;
    _depreciacionPorKm = prefs.getDouble(_keyDepreciacionPorKm) ?? 2.50;

    if (!_inicializado) {
      final rawViajes = prefs.getString(_keyViajesGuardados);
      if (rawViajes != null && rawViajes.isNotEmpty) {
        try {
          final decodificado = jsonDecode(rawViajes) as List<dynamic>;
          _viajesHoy
            ..clear()
            ..addAll(
              decodificado.map(
                (item) => ViajeRegistrado.fromMap(item as Map<dynamic, dynamic>),
              ),
            );
        } catch (_) {}
      }
      _inicializado = true;
    }

    if (_esAndroid) {
      try {
        await _channel.invokeMethod('updateCosts', _mapaCostos());
        final activo =
            await _channel.invokeMethod<bool>('isMonitoringActive') ?? false;
        _monitoreando = activo;
        await sincronizarViajesPendientes();
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<void> sincronizarViajesPendientes() async {
    if (!_esAndroid) return;
    try {
      final lista =
          await _channel.invokeMethod<List<dynamic>>('consumePendingTrips');
      if (lista != null && lista.isNotEmpty) {
        for (final item in lista) {
          if (item is Map) {
            _viajesHoy.insert(0, ViajeRegistrado.fromMap(item));
          }
        }
        await _guardarViajesEnPrefs();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> guardarCostos({
    required double gananciaPorKm,
    required double gastoCombustible,
    required double precioCombustible,
    required double tasaImpuestos,
    required double depreciacionPorKm,
  }) async {
    _gananciaPorKm = gananciaPorKm;
    _gastoCombustible = gastoCombustible > 0 ? gastoCombustible : 14.0;
    _precioCombustible = precioCombustible;
    _tasaImpuestos = tasaImpuestos;
    _depreciacionPorKm = depreciacionPorKm;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyGananciaPorKm, _gananciaPorKm);
    await prefs.setDouble(_keyGastoCombustible, _gastoCombustible);
    await prefs.setDouble(_keyPrecioCombustible, _precioCombustible);
    await prefs.setDouble(_keyTasaImpuestos, _tasaImpuestos);
    await prefs.setDouble(_keyDepreciacionPorKm, _depreciacionPorKm);

    if (_esAndroid) {
      try {
        await _channel.invokeMethod('updateCosts', _mapaCostos());
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<void> alternarMonitoreo() async {
    final nuevoEstado = !_monitoreando;
    _monitoreando = nuevoEstado;
    notifyListeners();

    if (_esAndroid) {
      try {
        if (nuevoEstado) {
          await _channel.invokeMethod('startMonitoring', _mapaCostos());
        } else {
          await _channel.invokeMethod('stopMonitoring');
        }
      } catch (_) {}
    }
  }

  /// Dispara un popup flotante real de prueba rotando entre Uber Driver, DiDi Conductor e inDrive
  /// usando exactamente los costos configurados en MisCostosScreen.
  Future<ViajeRegistrado> simularOfertaPopup() async {
    const ejemplos = [
      {'plataforma': 'Uber Driver', 'tarifaBruta': 125.0, 'distanciaKm': 7.5},
      {'plataforma': 'DiDi Conductor', 'tarifaBruta': 62.0, 'distanciaKm': 8.0},
      {'plataforma': 'inDrive', 'tarifaBruta': 160.0, 'distanciaKm': 9.2},
    ];

    final muestra = ejemplos[_indiceSimulacion % ejemplos.length];
    _indiceSimulacion++;

    final plataforma = muestra['plataforma'] as String;
    final tarifaBruta = (muestra['tarifaBruta'] as num).toDouble();
    final distanciaKm = (muestra['distanciaKm'] as num).toDouble();

    if (_esAndroid) {
      try {
        await _channel.invokeMethod('showSimulatedOffer', {
          ..._mapaCostos(),
          'plataforma': plataforma,
          'tarifaBruta': tarifaBruta,
          'distanciaKm': distanciaKm,
        });
      } catch (_) {}
    }

    return calcularAnalisis(
      plataforma: plataforma,
      tarifaBruta: tarifaBruta,
      distanciaKm: distanciaKm,
    );
  }

  ViajeRegistrado calcularAnalisis({
    required String plataforma,
    required double tarifaBruta,
    required double distanciaKm,
  }) {
    final rendimiento = _gastoCombustible > 0 ? _gastoCombustible : 14.0;
    final costoGasolina = (distanciaKm / rendimiento) * _precioCombustible;
    final costoImpuestos = tarifaBruta * (_tasaImpuestos / 100.0);
    final costoDepreciacion = distanciaKm * _depreciacionPorKm;
    final costoTotal = costoGasolina + costoImpuestos + costoDepreciacion;
    final gananciaNeta = tarifaBruta - costoTotal;
    final gananciaPorKmNeto = distanciaKm > 0 ? gananciaNeta / distanciaKm : 0.0;
    final conviene = gananciaPorKmNeto >= _gananciaPorKm;

    final ahora = DateTime.now();
    final hora12 = ahora.hour % 12 == 0 ? 12 : ahora.hour % 12;
    final minStr = ahora.minute.toString().padLeft(2, '0');
    final amPm = ahora.hour >= 12 ? 'PM' : 'AM';

    return ViajeRegistrado(
      plataforma: plataforma,
      hora: 'Hoy, ${hora12.toString().padLeft(2, '0')}:$minStr $amPm',
      tarifaBruta: tarifaBruta,
      distanciaKm: distanciaKm,
      costoGasolina: costoGasolina,
      costoImpuestos: costoImpuestos,
      costoDepreciacion: costoDepreciacion,
      gananciaNeta: gananciaNeta,
      gananciaPorKmNeto: gananciaPorKmNeto,
      conviene: conviene,
    );
  }

  Future<void> agregarViaje(ViajeRegistrado viaje) async {
    _viajesHoy.insert(0, viaje);
    await _guardarViajesEnPrefs();
    notifyListeners();
  }

  Future<void> _guardarViajesEnPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_viajesHoy.map((v) => v.toJson()).toList());
    await prefs.setString(_keyViajesGuardados, jsonStr);
  }

  Map<String, dynamic> _mapaCostos() => {
        'gananciaPorKm': _gananciaPorKm,
        'gastoCombustible': _gastoCombustible,
        'precioCombustible': _precioCombustible,
        'tasaImpuestos': _tasaImpuestos,
        'depreciacionPorKm': _depreciacionPorKm,
      };
}
