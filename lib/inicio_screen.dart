import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ad_gate_screen.dart';
import 'ad_gate_service.dart';
import 'viajes_service.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen>
    with TickerProviderStateMixin {
  // Controlador para el pulso rápido y enérgico cuando está ACTIVO (1.8s)
  late final AnimationController _activePulseController;
  late final Animation<double> _activeScaleAnimation;

  // Controlador para la respiración suave, lenta y elegante cuando está EN REPOSO (3.4s)
  late final AnimationController _idleBreathController;
  late final Animation<double> _idleScaleAnimation;
  late final Animation<double> _idleGlowAnimation;

  // Lógica de compuerta de anuncios de AdGate
  bool _bloqueado = false;
  Timer? _adGateTimer;

  @override
  void initState() {
    super.initState();
    // Animación ACTIVA
    _activePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _activeScaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _activePulseController, curve: Curves.easeInOut),
    );

    // Animación REPOSO (Respiración)
    _idleBreathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);

    _idleScaleAnimation = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _idleBreathController, curve: Curves.easeInOut),
    );
    _idleGlowAnimation = Tween<double>(begin: 0.08, end: 0.35).animate(
      CurvedAnimation(parent: _idleBreathController, curve: Curves.easeInOut),
    );

    // Verificar inmediatamente al entrar
    _actualizarBloqueo();

    // Verificación periódica rápida (cada 3 segundos) para reaccionar en cuanto expire el tiempo
    _adGateTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _actualizarBloqueo(),
    );
  }

  @override
  void dispose() {
    _activePulseController.dispose();
    _idleBreathController.dispose();
    _adGateTimer?.cancel();
    super.dispose();
  }

  Future<void> _actualizarBloqueo() async {
    final desbloqueado = await AdGateService.estaDesbloqueado();
    final servicio = ViajesService.instance;

    // Si expiró el tiempo de desbloqueo y el monitor estaba encendido, se detiene en seco
    if (!desbloqueado && servicio.monitoreando) {
      await servicio.detenerMonitoreo();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu sesión ha expirado. Ve los anuncios para continuar.'),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) setState(() => _bloqueado = !desbloqueado);
  }

  Future<void> _alPresionarBoton() async {
    final servicio = ViajesService.instance;
    final estabaActivo = servicio.monitoreando;

    // Solo se piden anuncios al INICIAR. Detener siempre es libre.
    if (!estabaActivo && !await AdGateService.estaDesbloqueado()) {
      if (!mounted) return;
      final completado = await AdGateScreen.abrir(context);
      if (!mounted) return;
      await _actualizarBloqueo();
      if (!mounted) return;
      if (!completado) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes ver los anuncios para iniciar el monitor'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final quedoActivo = await servicio.alternarMonitoreo();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final String mensaje;
    if (!estabaActivo && !quedoActivo) {
      mensaje = 'Activa "MasGa Lectura de Viajes" en Accesibilidad.';
    } else if (quedoActivo) {
      mensaje = 'Radar activo.';
    } else {
      mensaje = 'Radar detenido.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: quedoActivo ? const Color(0xFF059669) : const Color(0xFF161B22),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _actualizarBloqueo();
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
        final mostrarCandado = _bloqueado && !activo;

        // Gestión de controladores según el estado
        if (activo) {
          if (!_activePulseController.isAnimating) {
            _activePulseController.repeat(reverse: true);
          }
          if (_idleBreathController.isAnimating) {
            _idleBreathController.stop();
          }
        } else {
          if (_activePulseController.isAnimating) {
            _activePulseController.stop();
            _activePulseController.reset();
          }
          if (!_idleBreathController.isAnimating) {
            _idleBreathController.repeat(reverse: true);
          }
        }

        const bgProton = Color(0xFF0D1117);
        const cardBg = Color(0xFF161B22);
        const cardBorder = Color(0xFF30363D);
        const accentGreen = Color(0xFF10B981);
        const accentCyanIdle = Color(0xFF38BDF8); // Tono cian sutil para la respiración en reposo
        const accentAmber = Color(0xFFF59E0B); // Ámbar si requiere ver anuncios
        const textSecondary = Color(0xFF8B949E);

        return Scaffold(
          backgroundColor: bgProton,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final buttonSize = math.min(constraints.maxWidth * 0.72, 290.0);

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Header con estado
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'MASGA',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                      letterSpacing: 2.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: activo
                                              ? accentGreen
                                              : (mostrarCandado ? accentAmber : Colors.grey.shade600),
                                          boxShadow: activo
                                              ? [
                                                  BoxShadow(
                                                    color: accentGreen.withValues(alpha: 0.6),
                                                    blurRadius: 8,
                                                    spreadRadius: 2,
                                                  )
                                                ]
                                              : (mostrarCandado
                                                  ? [
                                                      BoxShadow(
                                                        color: accentAmber.withValues(alpha: 0.5),
                                                        blurRadius: 6,
                                                        spreadRadius: 1,
                                                      )
                                                    ]
                                                  : null),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        activo
                                            ? 'MONITOREANDO VIAJES'
                                            : (mostrarCandado
                                                ? 'REQUIERE DESBLOQUEO'
                                                : 'RADAR APAGADO'),
                                        style: TextStyle(
                                          color: activo
                                              ? Colors.white
                                              : (mostrarCandado ? accentAmber : textSecondary),
                                          fontSize: 13,
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
                                  border: Border.all(
                                    color: mostrarCandado ? accentAmber.withValues(alpha: 0.4) : cardBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      activo
                                          ? Icons.circle
                                          : (mostrarCandado ? Icons.lock_outline : Icons.pause_circle),
                                      color: activo
                                          ? accentGreen
                                          : (mostrarCandado ? accentAmber : textSecondary),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      activo
                                          ? 'ACTIVO'
                                          : (mostrarCandado ? 'BLOQUEADO' : 'APAGADO'),
                                      style: TextStyle(
                                        color: activo
                                            ? accentGreen
                                            : (mostrarCandado ? accentAmber : textSecondary),
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

                          const SizedBox(height: 16),

                          // 2. Botón central con respiración en reposo y pulso en activo (+ soporte AdGate)
                          Center(
                            child: AnimatedBuilder(
                              animation: activo ? _activeScaleAnimation : _idleBreathController,
                              builder: (context, child) {
                                final currentScale = activo
                                    ? _activeScaleAnimation.value
                                    : _idleScaleAnimation.value;
                                final idleGlow = _idleGlowAnimation.value;

                                final borderIdleColor = mostrarCandado
                                    ? Color.lerp(
                                        cardBorder,
                                        accentAmber.withValues(alpha: 0.6),
                                        (idleGlow - 0.08) / (0.35 - 0.08),
                                      )!
                                    : Color.lerp(
                                        cardBorder,
                                        accentCyanIdle.withValues(alpha: 0.5),
                                        (idleGlow - 0.08) / (0.35 - 0.08),
                                      )!;

                                final shadowGlowColor = mostrarCandado ? accentAmber : accentCyanIdle;

                                return Transform.scale(
                                  scale: currentScale,
                                  child: GestureDetector(
                                    onTap: _alPresionarBoton,
                                    child: Container(
                                      width: buttonSize,
                                      height: buttonSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: activo ? const Color(0xFF0F2D24) : cardBg,
                                        border: Border.all(
                                          color: activo ? accentGreen : borderIdleColor,
                                          width: activo ? 4 : 2.5,
                                        ),
                                        boxShadow: [
                                          if (activo) ...[
                                            BoxShadow(
                                              color: accentGreen.withValues(alpha: 0.35),
                                              blurRadius: 40,
                                              spreadRadius: 10,
                                            ),
                                            BoxShadow(
                                              color: accentGreen.withValues(alpha: 0.15),
                                              blurRadius: 70,
                                              spreadRadius: 20,
                                            ),
                                          ] else ...[
                                            // Halo de respiración sutil en reposo
                                            BoxShadow(
                                              color: shadowGlowColor.withValues(alpha: idleGlow),
                                              blurRadius: 32 * (idleGlow / 0.35),
                                              spreadRadius: 4 * (idleGlow / 0.35),
                                            ),
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.5),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            activo
                                                ? Icons.power_settings_new
                                                : (mostrarCandado ? Icons.lock_outline : Icons.play_arrow_rounded),
                                            size: buttonSize * 0.35,
                                            color: activo
                                                ? accentGreen
                                                : (mostrarCandado
                                                    ? accentAmber
                                                    : Color.lerp(
                                                        Colors.white70,
                                                        Colors.white,
                                                        (idleGlow - 0.08) / (0.35 - 0.08),
                                                      )),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            activo
                                                ? 'DETENER'
                                                : (mostrarCandado ? 'DESBLOQUEAR' : 'CONECTAR'),
                                            style: TextStyle(
                                              color: activo
                                                  ? accentGreen
                                                  : (mostrarCandado ? accentAmber : Colors.white),
                                              fontSize: buttonSize * 0.075,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2.5,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            activo
                                                ? 'Vigilando viajes'
                                                : (mostrarCandado
                                                    ? 'Ve ${AdGateService.anunciosRequeridos} anuncios'
                                                    : 'Toca para iniciar'),
                                            style: TextStyle(
                                              color: mostrarCandado ? accentAmber.withValues(alpha: 0.8) : textSecondary,
                                              fontSize: buttonSize * 0.044,
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

                          const SizedBox(height: 16),

                          // 3. Panel de Telemetría acomodado abajo
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                                      'DATOS DE HOY',
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
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricItem(
                                        label: 'Ganancia Estimada',
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

                          // 4. Lógica de "Probar Popup" preservada pero oculta visualmente
                          const Visibility(
                            visible: false,
                            maintainState: true,
                            child: _BotonProbarPopupOculto(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _BotonProbarPopupOculto extends StatelessWidget {
  const _BotonProbarPopupOculto();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => ViajesService.instance.simularOfertaPopup(),
      child: const Text('Probar Popup'),
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
