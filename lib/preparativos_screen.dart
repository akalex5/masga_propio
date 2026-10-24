import 'package:flutter/material.dart';
import 'pantalla_principal.dart';
import 'permisos_service.dart';

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

  /// Cada vez que el usuario regresa de la configuración de Android,
  /// re-verificamos el estado real de los 4 permisos.
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
    // Al volver de Ajustes de Accesibilidad, didChangeAppLifecycleState(resumed)
    // llamará automáticamente a _sincronizarPermisos().
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
    // Verifica si ya se activaron los 4 permisos
    final bool todosListos = _permisoNotificaciones &&
        _permisoSuperposicion &&
        _permisoBateria &&
        _permisoLectura;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _cargandoEstado
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          // Título y Subtítulo
                          const Text(
                            'Preparativos finales',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Configura estos permisos para que el cálculo de ganancias de tu app funcione en segundo plano sin interrupciones.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // 1. Tarjeta Notificaciones
                          _buildTarjetaPermiso(
                            titulo: 'Notificaciones',
                            descripcion:
                                'Necesario para mostrar una notificación permanente y evitar que el sistema detenga el servicio.',
                            icono: Icons.notifications_active,
                            activado: _permisoNotificaciones,
                            onTap: _activarNotificaciones,
                          ),

                          // 2. Tarjeta Superposición
                          _buildTarjetaPermiso(
                            titulo: 'Superposición sobre apps',
                            descripcion:
                                'Permite mostrar el popup de ganancias encima de tus apps de transporte mientras conduces.',
                            icono: Icons.layers,
                            activado: _permisoSuperposicion,
                            onTap: _activarSuperposicion,
                          ),

                          // 3. Tarjeta Batería
                          _buildTarjetaPermiso(
                            titulo: 'Optimización de batería',
                            descripcion:
                                'Desactiva las limitaciones para que el análisis de costos y kilómetros no se pause.',
                            icono: Icons.battery_saver,
                            activado: _permisoBateria,
                            onTap: _activarBateria,
                          ),

                          // 4. Tarjeta Lectura de pantalla (Accesibilidad)
                          _buildTarjetaPermiso(
                            titulo: 'Lectura de pantalla',
                            descripcion:
                                'Servicio de accesibilidad para extraer el precio y distancia de la pantalla automáticamente.',
                            icono: Icons.accessibility_new,
                            activado: _permisoLectura,
                            onTap: _activarLecturaPantalla,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Botón inferior principal (Compuerta de acceso)
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.9),
                          spreadRadius: 10,
                          blurRadius: 20,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed:
                                todosListos ? _continuarAPantallaPrincipal : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: todosListos
                                  ? const Color(0xFF2563EB)
                                  : Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: todosListos ? 2 : 0,
                            ),
                            child: Text(
                              todosListos
                                  ? 'Comenzar'
                                  : 'Completar lista para continuar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: todosListos
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Widget para construir cada tarjeta de forma reutilizable
  Widget _buildTarjetaPermiso({
    required String titulo,
    required String descripcion,
    required IconData icono,
    required bool activado,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícono de la izquierda
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: const Color(0xFF1E3A8A), size: 28),
          ),
          const SizedBox(width: 16),

          // Textos del centro
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Botón "Activar" o Check verde con texto "Activado"
          activado
              ? Column(
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.teal, size: 28),
                    const SizedBox(height: 2),
                    Text(
                      'Activado',
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Activar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
