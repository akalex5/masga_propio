import 'package:flutter/material.dart';
import 'pantalla_principal.dart';
import 'permisos_service.dart';
import 'tema_service.dart';

class PreparativosScreen extends StatefulWidget {
  const PreparativosScreen({super.key});

  @override
  State<PreparativosScreen> createState() => _PreparativosScreenState();
}

class _PreparativosScreenState extends State<PreparativosScreen>
    with WidgetsBindingObserver {
  bool _permisoNotificaciones = false;
  bool _permisoSuperposicion = false;
  bool _permisoBateria = false;
  bool _permisoLectura = false;
  bool _cargandoEstado = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sincronizarPermisos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sincronizarPermisos();
    }
  }

  Future<void> _sincronizarPermisos() async {
    final estado = await PermisosService.verificarEstadoActual();
    if (!mounted) return;
    setState(() {
      _permisoNotificaciones = estado.notificaciones;
      _permisoSuperposicion = estado.superposicion;
      _permisoBateria = estado.bateria;
      _permisoLectura = estado.lecturaPantalla;
      _cargandoEstado = false;
    });
  }

  Future<void> _activarNotificaciones() async {
    await PermisosService.solicitarNotificaciones();
    await _sincronizarPermisos();
  }

  Future<void> _activarSuperposicion() async {
    await PermisosService.solicitarSuperposicion();
    await _sincronizarPermisos();
  }

  Future<void> _activarBateria() async {
    await PermisosService.solicitarBateria();
    await _sincronizarPermisos();
  }

  Future<void> _activarLecturaPantalla() async {
    await PermisosService.solicitarAccesibilidad();
  }

  Future<void> _continuarAPantallaPrincipal() async {
    await PermisosService.marcarPreparativosCompletados();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PantallaPrincipal()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool todosListos = _permisoNotificaciones &&
        _permisoSuperposicion &&
        _permisoBateria &&
        _permisoLectura;

    return ListenableBuilder(
      listenable: TemaService.instance,
      builder: (context, _) {
        final esOscuro = TemaService.instance.esOscuro;
        final bgScreen = esOscuro ? TemaService.darkBg : TemaService.lightBg;
        final cardBg = esOscuro ? TemaService.darkCard : TemaService.lightCard;
        final cardBorder = esOscuro ? TemaService.darkBorder : TemaService.lightBorder;
        final textPrimary = esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary;
        final textSecondary = esOscuro ? TemaService.darkTextSecondary : TemaService.lightTextSecondary;

        return Scaffold(
          backgroundColor: bgScreen,
          body: SafeArea(
            child: _cargandoEstado
                ? const Center(
                    child: CircularProgressIndicator(color: TemaService.accentGreen),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              // Badge de estado
                              Text(
                                'CONFIGURACIÓN INICIAL',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Preparativos Finales',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Configura estos permisos para que el cálculo de ganancias funcione en segundo plano sin interrupciones.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // 1. Tarjeta Notificaciones
                              _buildTarjetaPermiso(
                                titulo: 'Notificaciones',
                                descripcion:
                                    'Muestra la barra activa para evitar que Android detenga el servicio de análisis.',
                                icono: Icons.notifications_active_outlined,
                                activado: _permisoNotificaciones,
                                onTap: _activarNotificaciones,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                esOscuro: esOscuro,
                              ),

                              // 2. Tarjeta Superposición
                              _buildTarjetaPermiso(
                                titulo: 'Superposición sobre apps',
                                descripcion:
                                    'Permite mostrar el popup flotante encima de DiDi, Uber o inDrive.',
                                icono: Icons.layers_outlined,
                                activado: _permisoSuperposicion,
                                onTap: _activarSuperposicion,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                esOscuro: esOscuro,
                              ),

                              // 3. Tarjeta Batería
                              _buildTarjetaPermiso(
                                titulo: 'Optimización de batería',
                                descripcion:
                                    'Desactiva el ahorro agresivo para que no se congele el lector mientras manejas.',
                                icono: Icons.battery_charging_full_outlined,
                                activado: _permisoBateria,
                                onTap: _activarBateria,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                esOscuro: esOscuro,
                              ),

                              // 4. Tarjeta Lectura de pantalla (Accesibilidad)
                              _buildTarjetaPermiso(
                                titulo: 'Lectura de pantalla',
                                descripcion:
                                    'Servicio de accesibilidad y OCR para extraer precio y kilómetros de la oferta.',
                                icono: Icons.radar_outlined,
                                activado: _permisoLectura,
                                onTap: _activarLecturaPantalla,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                esOscuro: esOscuro,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Botón inferior principal (Compuerta de acceso)
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: cardBg,
                          border: Border(top: BorderSide(color: cardBorder, width: 0.8)),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: todosListos ? _continuarAPantallaPrincipal : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: todosListos
                                  ? TemaService.accentGreen
                                  : (esOscuro ? const Color(0xFF21262D) : Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              elevation: todosListos ? 2 : 0,
                            ),
                            child: Text(
                              todosListos ? 'Comenzar a usar MasGa' : 'Completa los permisos para continuar',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: todosListos
                                    ? Colors.white
                                    : (esOscuro ? Colors.grey.shade500 : Colors.grey.shade600),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTarjetaPermiso({
    required String titulo,
    required String descripcion,
    required IconData icono,
    required bool activado,
    required VoidCallback onTap,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
    required bool esOscuro,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activado ? TemaService.accentGreen.withValues(alpha: 0.35) : cardBorder,
        ),
        boxShadow: [
          if (!esOscuro)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: activado
                  ? TemaService.accentGreen.withValues(alpha: 0.12)
                  : (esOscuro ? const Color(0xFF21262D) : const Color(0xFFF1F5F9)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icono,
              color: activado ? TemaService.accentGreen : textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descripcion,
                  style: TextStyle(fontSize: 12, color: textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          activado
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: TemaService.accentGreen, size: 20),
                    const SizedBox(width: 4),
                    const Text(
                      'Listo',
                      style: TextStyle(
                        color: TemaService.accentGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TemaService.accentGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Activar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
