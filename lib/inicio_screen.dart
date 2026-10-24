import 'package:flutter/material.dart';
import 'viajes_service.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servicio = ViajesService.instance;

    return ListenableBuilder(
      listenable: servicio,
      builder: (context, _) {
        final activo = servicio.monitoreando;
        final gananciaHoy = servicio.gananciaDeHoy;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '¡Hola, Eric! 👋',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ganancia de hoy: \$${gananciaHoy.toStringAsFixed(2)} MXN',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                // Indicador de estado del monitor
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: activo
                        ? Colors.teal.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activo ? Icons.radar : Icons.pause_circle_outline,
                        size: 18,
                        color: activo ? Colors.teal.shade700 : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        activo
                            ? 'Escuchando Uber Driver, DiDi e inDrive'
                            : 'Monitor detenido',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: activo ? Colors.teal.shade700 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Botón circular principal Iniciar / Detener
                ElevatedButton(
                  onPressed: () async {
                    final estabaActivo = servicio.monitoreando;
                    final quedoActivo = await servicio.alternarMonitoreo();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    final String mensaje;
                    if (!estabaActivo && !quedoActivo) {
                      mensaje =
                          'Activa "MasGa Lectura de Viajes" en Accesibilidad para detectar ofertas.';
                    } else if (quedoActivo) {
                      mensaje =
                          'Monitor activado en segundo plano. Puedes abrir Uber, DiDi o inDrive.';
                    } else {
                      mensaje = 'Monitor de viajes detenido.';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(mensaje),
                        backgroundColor: quedoActivo
                            ? Colors.teal.shade700
                            : const Color(0xFF1E3A8A),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activo
                        ? const Color(0xFFDC2626) // Rojo activo para Detener
                        : const Color(0xFF2563EB), // Azul para Iniciar
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(72),
                    elevation: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activo ? Icons.stop_rounded : Icons.play_arrow,
                        size: 40,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        activo ? 'Detener' : 'Iniciar',
                        style: const TextStyle(fontSize: 30, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Botón para probar el Popup Flotante (Semáforo) con los costos actuales
                OutlinedButton.icon(
                  onPressed: () async {
                    await servicio.simularOfertaPopup();
                  },
                  icon: const Icon(Icons.layers_outlined, color: Color(0xFF1E3A8A)),
                  label: const Text(
                    'Probar Popup de Viaje',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
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
}
