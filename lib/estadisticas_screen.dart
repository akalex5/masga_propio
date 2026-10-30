import 'package:flutter/material.dart';
import 'tema_service.dart';
import 'viajes_service.dart';

class EstadisticasScreen extends StatelessWidget {
  const EstadisticasScreen({super.key});

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
        final gananciaTotal = servicio.gananciaDeHoy;
        final totalKm = viajes.fold(0.0, (acc, v) => acc + v.distanciaKm);
        final promedioPorKm = totalKm > 0 ? (gananciaTotal / totalKm) : 0.0;
        final viajesConvenientes = viajes.where((v) => v.conviene).length;
        final porcentajeConveniencia = totalViajes > 0
            ? ((viajesConvenientes / totalViajes) * 100).round()
            : 0;

        return Scaffold(
          backgroundColor: bgScreen,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera
                Text(
                  'MÉTRICAS',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rendimiento Diario',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),

                const SizedBox(height: 18),

                // Tarjeta grande de Ingreso Diario
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'INGRESO ACUMULADO HOY',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: TemaService.accentGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '+ MXN',
                              style: TextStyle(
                                color: TemaService.accentGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '\$${gananciaTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Basado en los viajes aceptados durante el turno actual',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Cuadrícula de 4 tarjetas estadísticas (2x2)
                Row(
                  children: [
                    Expanded(
                      child: _TarjetaMetricaStat(
                        titulo: 'Tarifa Media',
                        valor: '\$${promedioPorKm.toStringAsFixed(2)}',
                        subtitulo: 'por kilómetro',
                        icono: Icons.trending_up,
                        colorIcono: TemaService.accentGreen,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        esOscuro: esOscuro,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TarjetaMetricaStat(
                        titulo: 'Efectividad',
                        valor: '$porcentajeConveniencia%',
                        subtitulo: 'viajes rentables',
                        icono: Icons.pie_chart_outline,
                        colorIcono: const Color(0xFF0284C7),
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        esOscuro: esOscuro,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _TarjetaMetricaStat(
                        titulo: 'Recorrido',
                        valor: '${totalKm.toStringAsFixed(1)}',
                        subtitulo: 'km acumulados',
                        icono: Icons.route_outlined,
                        colorIcono: const Color(0xFFFF7A00),
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        esOscuro: esOscuro,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TarjetaMetricaStat(
                        titulo: 'Turno',
                        valor: '$totalViajes',
                        subtitulo: 'viajes completados',
                        icono: Icons.check_circle_outline,
                        colorIcono: const Color(0xFF8B5CF6),
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        esOscuro: esOscuro,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Consejos de optimización
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: TemaService.accentGreen.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bolt, color: TemaService.accentGreen, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Optimiza tu ganancia por hora',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Configura tu meta en "Mis Costos" para filtrar alertas con pago bajo por kilómetro.',
                              style: TextStyle(color: textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TarjetaMetricaStat extends StatelessWidget {
  final String titulo;
  final String valor;
  final String subtitulo;
  final IconData icono;
  final Color colorIcono;
  final Color cardBg;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final bool esOscuro;

  const _TarjetaMetricaStat({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.icono,
    required this.colorIcono,
    required this.cardBg,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.esOscuro,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Icon(icono, color: colorIcono, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            style: TextStyle(color: textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
