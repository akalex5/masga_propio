import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../viajes_service.dart';

class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  bool get _soportaSqlite =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<Database?> get database async {
    if (!_soportaSqlite) return null;
    if (_db != null) return _db;
    _db = await _initDatabase();
    return _db;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'masga_local.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabla de historial de viajes locales en el teléfono
        await db.execute('''
          CREATE TABLE viajes_locales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plataforma TEXT NOT NULL,
            hora TEXT NOT NULL,
            tarifa_bruta REAL NOT NULL,
            distancia_km REAL NOT NULL,
            costo_gasolina REAL NOT NULL,
            costo_impuestos REAL NOT NULL,
            costo_depreciacion REAL NOT NULL,
            ganancia_neta REAL NOT NULL,
            ganancia_por_km_neto REAL NOT NULL,
            conviene INTEGER NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        // Tabla de configuración local de costos del vehículo
        await db.execute('''
          CREATE TABLE configuracion_costos (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            ganancia_por_km REAL NOT NULL DEFAULT 10.0,
            gasto_combustible REAL NOT NULL DEFAULT 14.0,
            precio_combustible REAL NOT NULL DEFAULT 24.0,
            tasa_impuestos REAL NOT NULL DEFAULT 8.0,
            depreciacion_por_km REAL NOT NULL DEFAULT 2.5
          )
        ''');

        // Insertar fila inicial por defecto
        await db.insert('configuracion_costos', {
          'id': 1,
          'ganancia_por_km': 10.0,
          'gasto_combustible': 14.0,
          'precio_combustible': 24.0,
          'tasa_impuestos': 8.0,
          'depreciacion_por_km': 2.5,
        });
      },
    );
  }

  Future<void> insertarViaje(ViajeRegistrado viaje) async {
    final db = await database;
    if (db == null) return;

    await db.insert(
      'viajes_locales',
      {
        'plataforma': viaje.plataforma,
        'hora': viaje.hora,
        'tarifa_bruta': viaje.tarifaBruta,
        'distancia_km': viaje.distanciaKm,
        'costo_gasolina': viaje.costoGasolina,
        'costo_impuestos': viaje.costoImpuestos,
        'costo_depreciacion': viaje.costoDepreciacion,
        'ganancia_neta': viaje.gananciaNeta,
        'ganancia_por_km_neto': viaje.gananciaPorKmNeto,
        'conviene': viaje.conviene ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ViajeRegistrado>> obtenerViajes() async {
    final db = await database;
    if (db == null) return [];

    final filas = await db.query(
      'viajes_locales',
      orderBy: 'id DESC',
      limit: 200,
    );

    return filas.map((f) {
      return ViajeRegistrado(
        plataforma: (f['plataforma'] as String?) ?? 'Uber Driver',
        hora: (f['hora'] as String?) ?? 'Hoy',
        tarifaBruta: (f['tarifa_bruta'] as num?)?.toDouble() ?? 0.0,
        distanciaKm: (f['distancia_km'] as num?)?.toDouble() ?? 0.0,
        costoGasolina: (f['costo_gasolina'] as num?)?.toDouble() ?? 0.0,
        costoImpuestos: (f['costo_impuestos'] as num?)?.toDouble() ?? 0.0,
        costoDepreciacion: (f['costo_depreciacion'] as num?)?.toDouble() ?? 0.0,
        gananciaNeta: (f['ganancia_neta'] as num?)?.toDouble() ?? 0.0,
        gananciaPorKmNeto: (f['ganancia_por_km_neto'] as num?)?.toDouble() ?? 0.0,
        conviene: ((f['conviene'] as int?) ?? 1) == 1,
      );
    }).toList();
  }

  Future<Map<String, double>?> obtenerCostos() async {
    final db = await database;
    if (db == null) return null;

    final filas = await db.query(
      'configuracion_costos',
      where: 'id = 1',
      limit: 1,
    );
    if (filas.isEmpty) return null;

    final f = filas.first;
    return {
      'gananciaPorKm': (f['ganancia_por_km'] as num?)?.toDouble() ?? 10.0,
      'gastoCombustible': (f['gasto_combustible'] as num?)?.toDouble() ?? 14.0,
      'precioCombustible': (f['precio_combustible'] as num?)?.toDouble() ?? 24.0,
      'tasaImpuestos': (f['tasa_impuestos'] as num?)?.toDouble() ?? 8.0,
      'depreciacionPorKm': (f['depreciacion_por_km'] as num?)?.toDouble() ?? 2.5,
    };
  }

  Future<void> guardarCostos({
    required double gananciaPorKm,
    required double gastoCombustible,
    required double precioCombustible,
    required double tasaImpuestos,
    required double depreciacionPorKm,
  }) async {
    final db = await database;
    if (db == null) return;

    await db.insert(
      'configuracion_costos',
      {
        'id': 1,
        'ganancia_por_km': gananciaPorKm,
        'gasto_combustible': gastoCombustible,
        'precio_combustible': precioCombustible,
        'tasa_impuestos': tasaImpuestos,
        'depreciacion_por_km': depreciacionPorKm,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
