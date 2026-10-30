import 'package:flutter/material.dart';
import 'tema_service.dart';
import 'viajes_service.dart';

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servicio = ViajesService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([servicio, TemaService.instance]),
      builder: (context, _) {
        final esOscuro = TemaService.instance.esOscuro;
        final bgScreen = esOscuro ? TemaService.darkBg : TemaService.lightBg;
        final cardBg = esOscuro ? TemaService.darkCard : TemaService.lightCard;
        final cardBorder = esOscuro ? TemaService.darkBorder : TemaService.lightBorder;
        final textPrimary = esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary;
        final textSecondary = esOscuro ? TemaService.darkTextSecondary : TemaService.lightTextSecondary;

        final viajes = servicio.viajesHoy;
        final totalViajes = viajes.length;
        final totalGanancia = servicio.gananciaDeHoy;
        final totalKm = viajes.fold(0.0, (acc, v) => acc + v.distanciaKm);
        final etiquetaViajes = totalViajes == 1 ? '1 viaje' : '$totalViajes viajes';

        return Scaffold(
          backgroundColor: bgScreen,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera estilizada
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HISTORIAL',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Viajes de Hoy',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Hoy',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Tarjeta resumen del día (Métricas destacadas)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      if (!esOscuro)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ganancia Neta',
                              style: TextStyle(color: textSecondary, fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${totalGanancia.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: TemaService.accentGreen,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 38, color: cardBorder),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registrados',
                                style: TextStyle(color: textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                etiquetaViajes,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 38, color: cardBorder),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Distancia',
                                style: TextStyle(color: textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${totalKm.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Lista de viajes
                Expanded(
                  child: viajes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 54,
                                color: textSecondary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sin viajes registrados hoy',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enciende el radar en Inicio para comenzar a capturar ofertas.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: viajes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final viaje = viajes[index];
                            final esConviene = viaje.conviene;

                            // Color de acento según plataforma
                            final Color colorPlat;
                            if (viaje.plataforma.toLowerCase().contains('didi')) {
                              colorPlat = const Color(0xFFFF7A00);
                            } else if (viaje.plataforma.toLowerCase().contains('uber')) {
                              colorPlat = esOscuro ? Colors.white : const Color(0xFF0F172A);
                            } else {
                              colorPlat = TemaService.accentGreen;
                            }

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder),
                                boxShadow: [
                                  if (!esOscuro)
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Indicador semáforo lateral
                                  Container(
                                    width: 4,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: esConviene ? TemaService.accentGreen : TemaService.accentRed,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Datos principales del viaje
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              viaje.plataforma,
                                              style: TextStyle(
                                                color: colorPlat,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '• ${viaje.hora}',
                                              style: TextStyle(color: textSecondary, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${viaje.distanciaKm.toStringAsFixed(1)} km totales • \$${viaje.gananciaPorKmNeto.toStringAsFixed(2)}/km',
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Monto y badge
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${viaje.tarifaBruta.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: esConviene
                                              ? TemaService.accentGreen.withValues(alpha: 0.15)
                                              : TemaService.accentRed.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          esConviene ? 'Conviene' : 'No conviene',
                                          style: TextStyle(
                                            color: esConviene ? TemaService.accentGreen : TemaService.accentRed,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
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
          ),
        );
      },
    );
  }
}
