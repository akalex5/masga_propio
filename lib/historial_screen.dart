import 'package:flutter/material.dart';
import 'viajes_service.dart';

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servicio = ViajesService.instance;

    return ListenableBuilder(
      listenable: servicio,
      builder: (context, _) {
        final viajes = servicio.viajesHoy;
        final totalViajes = viajes.length;
        final totalGanancia = servicio.gananciaDeHoy;
        final etiquetaViajes = totalViajes == 1 ? '1 viaje' : '$totalViajes viajes';

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Historial de viajes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  Text('Hoy ▼', style: TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Total: $etiquetaViajes | \$${totalGanancia.toStringAsFixed(2)} MXN',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: viajes.isEmpty
                    ? const Center(
                        child: Text(
                          'Aún no hay viajes registrados hoy.\nInicia el monitor o prueba el popup en Inicio.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: viajes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final v = viajes[index];
                          final colorMonto = v.conviene
                              ? Colors.teal
                              : const Color(0xFFDC2626);
                          final signo = v.gananciaNeta >= 0 ? '+' : '';

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${v.plataforma} • ${v.hora}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    Text(
                                      '$signo\$${v.gananciaNeta.toStringAsFixed(2)} MXN',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: colorMonto,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Bruto: \$${v.tarifaBruta.toStringAsFixed(2)} • ${v.distanciaKm.toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Text(
                                      '\$${v.gananciaPorKmNeto.toStringAsFixed(2)} / km neto',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colorMonto,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
