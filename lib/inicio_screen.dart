import 'package:flutter/material.dart';
import 'viajes_service.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicio = ViajesService.instance;

    return ListenableBuilder(
      listenable: servicio,
      builder: (context, _) {
        final activo = servicio.monitoreando;
        final gananciaHoy = servicio.gananciaDeHoy;
        final totalViajes = servicio.viajesHoy.length;
        final totalKm = servicio.viajesHoy.fold(0.0, (acc, v) => acc + v.distanciaKm);
        final promedioKm = totalKm > 0 ? (gananciaHoy / totalKm) : servicio.gananciaPorKm;

        if (activo) {
          if (!_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }
        } else {
          if (_pulseController.isAnimating) {
            _pulseController.stop();
            _pulseController.reset();
          }
        }

        // Paleta inspirada en Proton VPN (Dark Mode profundo + esmeralda neón)
        const bgProton = Color(0xFF0D1117);
        const cardBg = Color(0xFF161B22);
        const cardBorder = Color(0xFF30363D);
        const accentGreen = Color(0xFF10B981);
        const textSecondary = Color(0xFF8B949E);

        return Scaffold(
          backgroundColor: bgProton,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header con estado y app activa
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MASGA RADAR',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: activo ? accentGreen : Colors.grey.shade600,
                                  boxShadow: activo
                                      ? [
                                          BoxShadow(
                                            color: accentGreen.withValues(alpha: 0.6),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                activo ? 'MONITOREANDO OFERTAS' : 'RADAR EN ESPERA',
                                style: TextStyle(
                                  color: activo ? Colors.white : textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              activo ? Icons.security : Icons.shield_outlined,
                              color: activo ? accentGreen : textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              activo ? 'PROTEGIDO' : 'PAUSADO',
                              style: TextStyle(
                                color: activo ? accentGreen : textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // 2. Botón principal interactivo estilo Proton Quick Connect
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final scale = activo ? _pulseAnimation.value : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: GestureDetector(
                            onTap: () async {
                              final estabaActivo = servicio.monitoreando;
                              final quedoActivo = await servicio.alternarMonitoreo();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              final String mensaje;
                              if (!estabaActivo && !quedoActivo) {
                                mensaje = 'Activa "MasGa Lectura de Viajes" en Accesibilidad.';
                              } else if (quedoActivo) {
                                mensaje = 'Radar activo. Vigilando DiDi, Uber e inDrive.';
                              } else {
                                mensaje = 'Radar detenido.';
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(mensaje),
                                  backgroundColor: quedoActivo ? const Color(0xFF059669) : cardBg,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: activo ? const Color(0xFF0F2D24) : cardBg,
                                border: Border.all(
                                  color: activo ? accentGreen : cardBorder,
                                  width: activo ? 3 : 2,
                                ),
                                boxShadow: [
                                  if (activo) ...[
                                    BoxShadow(
                                      color: accentGreen.withValues(alpha: 0.35),
                                      blurRadius: 36,
                                      spreadRadius: 8,
                                    ),
                                    BoxShadow(
                                      color: accentGreen.withValues(alpha: 0.15),
                                      blurRadius: 60,
                                      spreadRadius: 16,
                                    ),
                                  ] else
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    activo ? Icons.power_settings_new : Icons.play_arrow_rounded,
                                    size: 58,
                                    color: activo ? accentGreen : Colors.white,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    activo ? 'DETENER' : 'CONECTAR',
                                    style: TextStyle(
                                      color: activo ? accentGreen : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    activo ? 'Vigilando viajes' : 'Toca para iniciar',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 38),

                  // 3. Telemetría y Métricas en Tarjetas Oscuras (Estilo Proton stats)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TELEMETRÍA DE HOY',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Icon(Icons.tune, color: textSecondary, size: 16),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricItem(
                                label: 'Ganancia estimada',
                                value: '\$${gananciaHoy.toStringAsFixed(2)}',
                                unit: 'MXN',
                                highlightColor: accentGreen,
                              ),
                            ),
                            Container(width: 1, height: 44, color: cardBorder),
                            Expanded(
                              child: _MetricItem(
                                label: 'Tarifa / Km',
                                value: '\$${promedioKm.toStringAsFixed(2)}',
                                unit: '/km',
                                highlightColor: Colors.white,
                              ),
                            ),
                            Container(width: 1, height: 44, color: cardBorder),
                            Expanded(
                              child: _MetricItem(
                                label: 'Viajes',
                                value: '$totalViajes',
                                unit: 'registros',
                                highlightColor: const Color(0xFF60A5FA),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Selector de Plataformas Vigiladas (Estilo selector de servidores Proton)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PLATAFORMAS CONECTADAS',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _PlatformBadge(
                              title: 'DiDi Conductor',
                              mode: 'OCR en vivo',
                              isActive: activo,
                              accentColor: const Color(0xFFFF7A00),
                            ),
                            _PlatformBadge(
                              title: 'Uber Driver',
                              mode: 'Nodos UI',
                              isActive: activo,
                              accentColor: Colors.white,
                            ),
                            _PlatformBadge(
                              title: 'inDrive',
                              mode: 'Nodos UI',
                              isActive: activo,
                              accentColor: const Color(0xFF10B981),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Botón discreto de testeo de popup
                  OutlinedButton.icon(
                    onPressed: () async {
                      await servicio.simularOfertaPopup();
                    },
                    icon: const Icon(Icons.flash_on, color: accentGreen, size: 18),
                    label: const Text(
                      'PROBAR POPUP FLOTANTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: cardBorder),
                      backgroundColor: cardBg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color highlightColor;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: highlightColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  final String title;
  final String mode;
  final bool isActive;
  final Color accentColor;

  const _PlatformBadge({
    required this.title,
    required this.mode,
    required this.isActive,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? accentColor.withValues(alpha: 0.3) : const Color(0xFF30363D),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? accentColor : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            mode,
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
