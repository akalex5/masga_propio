import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ad_gate_screen.dart';
import 'supabase_service.dart';
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

  Timer? _relojTurnoTimer;
  bool _procesandoDesbloqueo = false;

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

    // Sincronizar con Supabase al abrir Inicio de manera segura tras el primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        SupabaseService.instance.cargarEstadoConductor();
      }
    });

    // Reloj para actualizar el contador regresivo y verificar expiración del turno de 4h
    _relojTurnoTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _verificarTurnoEnTiempoReal(),
    );
  }

  @override
  void dispose() {
    _activePulseController.dispose();
    _idleBreathController.dispose();
    _relojTurnoTimer?.cancel();
    super.dispose();
  }

  Future<void> _verificarTurnoEnTiempoReal() async {
    final supa = SupabaseService.instance;
    final viajes = ViajesService.instance;

    if (!supa.turnoActivo && viajes.monitoreando) {
      await viajes.detenerMonitoreo();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu turno de 4 horas ha finalizado. Usa 3 llaves para desbloquear otro turno.',
            ),
            backgroundColor: TemaService.accentAmber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _alPresionarBotonCentral() async {
    if (_procesandoDesbloqueo) return;

    final supa = SupabaseService.instance;
    final servicio = ViajesService.instance;

    // ESTADO 1: APP BLOQUEADA (Fuera de turno)
    if (!supa.turnoActivo) {
      if (supa.balanceLlaves < SupabaseService.costoDesbloqueoLlaves) {
        _mostrarModalLlavesInsuficientes();
        return;
      }

      // Tiene >= 3 llaves: Desbloquear turno de 4 horas en Supabase
      setState(() => _procesandoDesbloqueo = true);
      final resultado = await supa.desbloquearTurno4Horas();
      if (!mounted) return;
      setState(() => _procesandoDesbloqueo = false);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado.mensaje),
          backgroundColor: resultado.exito
              ? TemaService.accentGreen
              : TemaService.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ESTADO 2: APP ACTIVA (Dentro del turno de 4 horas) -> Conectar / Detener Radar
    final estabaActivo = servicio.monitoreando;
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
        backgroundColor:
            quedoActivo ? const Color(0xFF059669) : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarModalLlavesInsuficientes() {
    final esOscuro = TemaService.instance.esOscuro;
    final dialogBg = esOscuro ? TemaService.darkCard : TemaService.lightCard;
    final border = esOscuro ? TemaService.darkBorder : TemaService.lightBorder;
    final textPrimary =
        esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary;
    final textSecondary = esOscuro
        ? TemaService.darkTextSecondary
        : TemaService.lightTextSecondary;
    final balance = SupabaseService.instance.balanceLlaves;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: border),
          ),
          title: Row(
            children: [
              const Icon(Icons.vpn_key_rounded, color: TemaService.accentAmber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Llaves insuficientes ($balance/3)',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'No tienes suficientes llaves. Necesitas 3 llaves para iniciar tu turno de 4 horas.\n\n¿Quieres obtener una ahora viendo un anuncio?',
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(color: textSecondary),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _alPresionarObtenerLlave();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TemaService.accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.movie_creation_outlined, size: 18),
              label: const Text('Ver anuncio (+1 🔑)'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _alPresionarObtenerLlave() async {
    final supa = SupabaseService.instance;

    if (supa.balanceLlaves >= SupabaseService.maxLlaves) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ya tienes el máximo de llaves permitidas (9/9). Gasta llaves iniciando tu turno para poder ver más anuncios.',
          ),
          backgroundColor: TemaService.accentAmber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await AdGateScreen.obtenerLlave(context);
  }

  @override
  Widget build(BuildContext context) {
    final servicio = ViajesService.instance;
    final supa = SupabaseService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([servicio, TemaService.instance, supa]),
      builder: (context, _) {
        final turnoActivo = supa.turnoActivo;
        final balanceLlaves = supa.balanceLlaves;
        final billeteraLlena = balanceLlaves >= SupabaseService.maxLlaves;

        final activo = turnoActivo && servicio.monitoreando;
        final gananciaHoy = servicio.gananciaDeHoy;
        final totalViajes = servicio.viajesHoy.length;
        final totalKm =
            servicio.viajesHoy.fold(0.0, (acc, v) => acc + v.distanciaKm);
        final promedioKm =
            totalKm > 0 ? (gananciaHoy / totalKm) : servicio.gananciaPorKm;
        final mostrarCandado = !turnoActivo;

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
        final cardBorder =
            esOscuro ? TemaService.darkBorder : TemaService.lightBorder;
        final textPrimary = esOscuro
            ? TemaService.darkTextPrimary
            : TemaService.lightTextPrimary;
        final textSecondary = esOscuro
            ? TemaService.darkTextSecondary
            : TemaService.lightTextSecondary;

        const accentGreen = TemaService.accentGreen;
        const accentAmber = TemaService.accentAmber;
        final accentCyanIdle =
            esOscuro ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

        return Scaffold(
          backgroundColor: bgScreen,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final buttonSize = math.min(constraints.maxWidth * 0.66, 265.0);

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Header con estado e Indicador de Billetera (🔑 [balance_llaves] / 9)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Image.asset(
                                    esOscuro
                                        ? 'assets/logos/MASGA_LOGO LARGO OSCURO.png'
                                        : 'assets/logos/MASGA_LOGO largo blanco.png',
                                    height: 18,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: activo
                                              ? accentGreen
                                              : (mostrarCandado
                                                  ? accentAmber
                                                  : accentCyanIdle),
                                          boxShadow: activo
                                              ? [
                                                  BoxShadow(
                                                    color: accentGreen
                                                        .withValues(alpha: 0.6),
                                                    blurRadius: 8,
                                                    spreadRadius: 2,
                                                  )
                                                ]
                                              : (mostrarCandado
                                                  ? [
                                                      BoxShadow(
                                                        color: accentAmber
                                                            .withValues(
                                                                alpha: 0.5),
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
                                                ? 'FUERA DE TURNO'
                                                : 'TURNO ACTIVO'),
                                        style: TextStyle(
                                          color: activo
                                              ? (esOscuro
                                                  ? Colors.white
                                                  : accentGreen)
                                              : (mostrarCandado
                                                  ? accentAmber
                                                  : accentCyanIdle),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Indicador de Billetera: 🔑 [balance_llaves] / 9
                              GestureDetector(
                                onTap: _alPresionarObtenerLlave,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: balanceLlaves >= 3
                                          ? accentGreen.withValues(alpha: 0.5)
                                          : accentAmber.withValues(alpha: 0.5),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      if (!esOscuro)
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '🔑',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$balanceLlaves / ${SupabaseService.maxLlaves}',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 2. Botón central y botón secundario de anuncios
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: AnimatedBuilder(
                                  animation: activo
                                      ? _activeScaleAnimation
                                      : _idleBreathController,
                                  builder: (context, child) {
                                    final currentScale = activo
                                        ? _activeScaleAnimation.value
                                        : _idleScaleAnimation.value;
                                    final idleGlow = _idleGlowAnimation.value;

                                    final borderIdleColor = mostrarCandado
                                        ? Color.lerp(
                                            cardBorder,
                                            accentAmber.withValues(alpha: 0.65),
                                            (idleGlow - 0.08) / (0.35 - 0.08),
                                          )!
                                        : Color.lerp(
                                            cardBorder,
                                            accentCyanIdle.withValues(
                                                alpha: esOscuro ? 0.55 : 0.45),
                                            (idleGlow - 0.08) / (0.35 - 0.08),
                                          )!;

                                    final shadowGlowColor = mostrarCandado
                                        ? accentAmber
                                        : accentCyanIdle;

                                    final botonBg = activo
                                        ? (esOscuro
                                            ? const Color(0xFF0F2D24)
                                            : const Color(0xFFECFDF5))
                                        : cardBg;

                                    return Transform.scale(
                                      scale: currentScale,
                                      child: GestureDetector(
                                        onTap: _alPresionarBotonCentral,
                                        child: Container(
                                          width: buttonSize,
                                          height: buttonSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: botonBg,
                                            border: Border.all(
                                              color: activo
                                                  ? accentGreen
                                                  : borderIdleColor,
                                              width: activo ? 4 : 2.5,
                                            ),
                                            boxShadow: [
                                              if (activo) ...[
                                                BoxShadow(
                                                  color: accentGreen.withValues(
                                                      alpha: 0.35),
                                                  blurRadius: 40,
                                                  spreadRadius: 10,
                                                ),
                                                BoxShadow(
                                                  color: accentGreen.withValues(
                                                      alpha: 0.15),
                                                  blurRadius: 70,
                                                  spreadRadius: 20,
                                                ),
                                              ] else ...[
                                                BoxShadow(
                                                  color: shadowGlowColor
                                                      .withValues(
                                                          alpha: esOscuro
                                                              ? idleGlow
                                                              : idleGlow * 0.7),
                                                  blurRadius:
                                                      32 * (idleGlow / 0.35),
                                                  spreadRadius:
                                                      4 * (idleGlow / 0.35),
                                                ),
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(
                                                          alpha: esOscuro
                                                              ? 0.45
                                                              : 0.08),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ],
                                          ),
                                          child: _procesandoDesbloqueo
                                              ? const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: accentAmber,
                                                  ),
                                                )
                                              : Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16.0),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        activo
                                                            ? Icons
                                                                .power_settings_new
                                                            : (mostrarCandado
                                                                ? Icons
                                                                    .lock_outline
                                                                : Icons
                                                                    .play_arrow_rounded),
                                                        size:
                                                            buttonSize * 0.33,
                                                        color: activo
                                                            ? accentGreen
                                                            : (mostrarCandado
                                                                ? accentAmber
                                                                : accentCyanIdle),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        activo
                                                            ? 'DETENER'
                                                            : (mostrarCandado
                                                                ? 'DESBLOQUEAR'
                                                                : 'CONECTAR'),
                                                        style: TextStyle(
                                                          color: activo
                                                              ? accentGreen
                                                              : (mostrarCandado
                                                                  ? accentAmber
                                                                  : textPrimary),
                                                          fontSize: buttonSize *
                                                              0.072,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          letterSpacing: 2.2,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        mostrarCandado
                                                            ? 'Costo: 3 Llaves\n(Acceso por 4 horas)'
                                                            : 'Acceso termina en:\n${supa.textoTiempoRestante}',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          color: mostrarCandado
                                                              ? accentAmber
                                                                  .withValues(
                                                                      alpha:
                                                                          0.85)
                                                              : textSecondary,
                                                          fontSize: buttonSize *
                                                              0.043,
                                                          height: 1.25,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Botón Secundario: "🎬 Obtener llave (Ver video)" o "Billetera llena (9/9)"
                              SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: _alPresionarObtenerLlave,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: billeteraLlena
                                        ? (esOscuro
                                            ? const Color(0xFF21262D)
                                            : const Color(0xFFE2E8F0))
                                        : cardBg,
                                    foregroundColor: billeteraLlena
                                        ? textSecondary
                                        : textPrimary,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                      side: BorderSide(
                                        color: billeteraLlena
                                            ? cardBorder
                                            : accentGreen.withValues(
                                                alpha: 0.6),
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                  icon: Text(
                                    billeteraLlena ? '🔒' : '🎬',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  label: Text(
                                    billeteraLlena
                                        ? 'Billetera llena (9/9)'
                                        : 'Obtener llave (Ver video)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: billeteraLlena
                                          ? textSecondary
                                          : textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 3. Panel de Telemetría adaptado a Claro y Oscuro
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                    Icon(Icons.tune,
                                        color: textSecondary, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricItem(
                                        label: 'Ganancia Estimada',
                                        value:
                                            '\$${gananciaHoy.toStringAsFixed(2)}',
                                        unit: 'MXN',
                                        highlightColor: accentGreen,
                                        esOscuro: esOscuro,
                                      ),
                                    ),
                                    Container(
                                        width: 1, height: 44, color: cardBorder),
                                    Expanded(
                                      child: _MetricItem(
                                        label: 'Tarifa / Km',
                                        value:
                                            '\$${promedioKm.toStringAsFixed(2)}',
                                        unit: '/km',
                                        highlightColor: textPrimary,
                                        esOscuro: esOscuro,
                                      ),
                                    ),
                                    Container(
                                        width: 1, height: 44, color: cardBorder),
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
    final subColor = esOscuro
        ? TemaService.darkTextSecondary
        : TemaService.lightTextSecondary;

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
