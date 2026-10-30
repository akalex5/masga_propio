import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ad_gate_screen.dart';
import 'ad_gate_service.dart';
import 'tema_service.dart';
import 'viajes_service.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen>
    with TickerProviderStateMixin {
  late final AnimationController _activePulseController;
  late final Animation<double> _activeScaleAnimation;

  late final AnimationController _idleBreathController;
  late final Animation<double> _idleScaleAnimation;
  late final Animation<double> _idleGlowAnimation;

  bool _bloqueado = false;
  Timer? _adGateTimer;

  @override
  void initState() {
    super.initState();
    _activePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _activeScaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _activePulseController, curve: Curves.easeInOut),
    );

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

    _actualizarBloqueo();
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

    if (!desbloqueado && servicio.monitoreando) {
      await servicio.detenerMonitoreo();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu sesión ha expirado. Ve los anuncios para continuar.'),
            backgroundColor: TemaService.accentAmber,
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
        backgroundColor: quedoActivo ? const Color(0xFF059669) : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _actualizarBloqueo();
  }

  @override
  Widget build(BuildContext context) {
    final servicio = ViajesService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([servicio, TemaService.instance]),
      builder: (context, _) {
        final activo = servicio.monitoreando;
        final gananciaHoy = servicio.gananciaDeHoy;
        final totalViajes = servicio.viajesHoy.length;
        final totalKm = servicio.viajesHoy.fold(0.0, (acc, v) => acc + v.distanciaKm);
        final promedioKm = totalKm > 0 ? (gananciaHoy / totalKm) : servicio.gananciaPorKm;
        final mostrarCandado = _bloqueado && !activo;

        // Gestión de controladores de animación
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

        final esOscuro = TemaService.instance.esOscuro;
        final bgScreen = esOscuro ? TemaService.darkBg : TemaService.lightBg;
        final cardBg = esOscuro ? TemaService.darkCard : TemaService.lightCard;
        final cardBorder = esOscuro ? TemaService.darkBorder : TemaService.lightBorder;
        final textPrimary = esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary;
        final textSecondary = esOscuro ? TemaService.darkTextSecondary : TemaService.lightTextSecondary;

        const accentGreen = TemaService.accentGreen;
        const accentAmber = TemaService.accentAmber;
        final accentCyanIdle = esOscuro ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

        return Scaffold(
          backgroundColor: bgScreen,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final buttonSize = math.min(constraints.maxWidth * 0.72, 290.0);

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
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
                                  Text(
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
                                              : (mostrarCandado ? accentAmber : Colors.grey.shade500),
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
                                              ? (esOscuro ? Colors.white : accentGreen)
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
                                  boxShadow: [
                                    if (!esOscuro)
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
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

                          // 2. Botón central adaptado a Claro y Oscuro
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
                                        accentCyanIdle.withValues(alpha: esOscuro ? 0.5 : 0.4),
                                        (idleGlow - 0.08) / (0.35 - 0.08),
                                      )!;

                                final shadowGlowColor = mostrarCandado ? accentAmber : accentCyanIdle;

                                // Colores de fondo del botón según modo
                                final botonBg = activo
                                    ? (esOscuro ? const Color(0xFF0F2D24) : const Color(0xFFECFDF5))
                                    : cardBg;

                                return Transform.scale(
                                  scale: currentScale,
                                  child: GestureDetector(
                                    onTap: _alPresionarBoton,
                                    child: Container(
                                      width: buttonSize,
                                      height: buttonSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: botonBg,
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
                                              color: shadowGlowColor.withValues(alpha: esOscuro ? idleGlow : idleGlow * 0.7),
                                              blurRadius: 32 * (idleGlow / 0.35),
                                              spreadRadius: 4 * (idleGlow / 0.35),
                                            ),
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: esOscuro ? 0.45 : 0.08),
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
                                                    : (esOscuro
                                                        ? Color.lerp(Colors.white70, Colors.white, (idleGlow - 0.08) / (0.35 - 0.08))
                                                        : Color.lerp(textSecondary, textPrimary, (idleGlow - 0.08) / (0.35 - 0.08)))),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            activo
                                                ? 'DETENER'
                                                : (mostrarCandado ? 'DESBLOQUEAR' : 'CONECTAR'),
                                            style: TextStyle(
                                              color: activo
                                                  ? accentGreen
                                                  : (mostrarCandado ? accentAmber : textPrimary),
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

                          // 3. Panel de Telemetría adaptado a Claro y Oscuro
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                        esOscuro: esOscuro,
                                      ),
                                    ),
                                    Container(width: 1, height: 44, color: cardBorder),
                                    Expanded(
                                      child: _MetricItem(
                                        label: 'Tarifa / Km',
                                        value: '\$${promedioKm.toStringAsFixed(2)}',
                                        unit: '/km',
                                        highlightColor: textPrimary,
                                        esOscuro: esOscuro,
                                      ),
                                    ),
                                    Container(width: 1, height: 44, color: cardBorder),
                                    Expanded(
                                      child: _MetricItem(
                                        label: 'Viajes',
                                        value: '$totalViajes',
                                        unit: 'registros',
                                        highlightColor: const Color(0xFF0284C7),
                                        esOscuro: esOscuro,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // 4. Lógica de "Probar Popup" oculta
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
  final bool esOscuro;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.highlightColor,
    required this.esOscuro,
  });

  @override
  Widget build(BuildContext context) {
    final subColor = esOscuro ? TemaService.darkTextSecondary : TemaService.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: subColor, fontSize: 11),
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
                style: TextStyle(color: subColor, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
