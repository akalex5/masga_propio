import 'ad_banner_widget.dart';
import 'package:flutter/material.dart';
import 'estadisticas_screen.dart';
import 'historial_screen.dart';
import 'inicio_screen.dart';
import 'login_screen.dart';
import 'mis_costos_screen.dart';
import 'supabase_service.dart';
import 'tema_service.dart';
import 'viajes_service.dart';

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal>
    with WidgetsBindingObserver {
  int _indiceActual = 0;

  final List<Widget> _pantallas = [
    const InicioScreen(),
    const HistorialScreen(),
    const EstadisticasScreen(),
    const MisCostosScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ViajesService.instance.inicializar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ViajesService.instance.sincronizarViajesPendientes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TemaService.instance,
      builder: (context, _) {
        final esOscuro = TemaService.instance.esOscuro;
        final bgActual = esOscuro ? TemaService.darkBg : TemaService.lightBg;
        final barBg = esOscuro ? TemaService.darkCard : TemaService.lightCard;
        final borderActual = esOscuro ? TemaService.darkBorder : TemaService.lightBorder;
        final iconColor = esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary;
        final textSecondary = esOscuro ? TemaService.darkTextSecondary : TemaService.lightTextSecondary;

        return Scaffold(
          backgroundColor: bgActual,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: iconColor),
            title: Image.asset(
              esOscuro
                  ? 'assets/logos/MASGA_LOGO LARGO OSCURO.png'
                  : 'assets/logos/MASGA_LOGO largo blanco.png',
              height: 28,
              fit: BoxFit.contain,
            ),
            actions: [
              // Botón rápido en la esquina superior para alternar tema
              IconButton(
                tooltip: 'Modo de visualización',
                icon: Icon(
                  esOscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: iconColor,
                ),
                onPressed: () => _mostrarDialogoSeleccionTema(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: const MenuLateral(),
          body: _pantallas[_indiceActual],
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderActual, width: 0.8)),
                ),
                child: BottomNavigationBar(
                  currentIndex: _indiceActual,
                  onTap: (index) {
                    setState(() {
                      _indiceActual = index;
                    });
                  },
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: barBg,
                  selectedItemColor: TemaService.accentGreen,
                  unselectedItemColor: textSecondary,
                  elevation: 0,
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
                    BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
                    BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Estadísticas'),
                    BottomNavigationBarItem(icon: Icon(Icons.calculate_outlined), label: 'Mis costos'),
                  ],
                ),
              ),
              const SafeArea(
                child: AdBannerWidget(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarDialogoSeleccionTema(BuildContext context) {
    final tema = TemaService.instance;
    final esOscuro = tema.esOscuro;
    final dialogBg = esOscuro ? TemaService.darkCard : TemaService.lightCard;
    final textPrimary = esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: esOscuro ? TemaService.darkBorder : TemaService.lightBorder),
          ),
          title: Text(
            'Tema de la aplicación',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OpcionTemaTile(
                titulo: 'Claro',
                subtitulo: 'Fondo limpio y texto oscuro',
                icono: Icons.light_mode,
                modo: ThemeMode.light,
                modoActual: tema.themeMode,
                onSeleccionar: (m) {
                  tema.cambiarModo(m);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
              _OpcionTemaTile(
                titulo: 'Oscuro',
                subtitulo: 'Fondo grafito estilo Proton',
                icono: Icons.dark_mode,
                modo: ThemeMode.dark,
                modoActual: tema.themeMode,
                onSeleccionar: (m) {
                  tema.cambiarModo(m);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
              _OpcionTemaTile(
                titulo: 'Sistema',
                subtitulo: 'Sigue la configuración de tu teléfono',
                icono: Icons.settings_brightness,
                modo: ThemeMode.system,
                modoActual: tema.themeMode,
                onSeleccionar: (m) {
                  tema.cambiarModo(m);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OpcionTemaTile extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final ThemeMode modo;
  final ThemeMode modoActual;
  final ValueChanged<ThemeMode> onSeleccionar;

  const _OpcionTemaTile({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.modo,
    required this.modoActual,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final seleccionada = modo == modoActual;
    final esOscuro = TemaService.instance.esOscuro;
    final tileBg = seleccionada
        ? TemaService.accentGreen.withValues(alpha: 0.12)
        : (esOscuro ? TemaService.darkBg : const Color(0xFFF1F5F9));
    final borderColor = seleccionada
        ? TemaService.accentGreen
        : (esOscuro ? TemaService.darkBorder : TemaService.lightBorder);

    return InkWell(
      onTap: () => onSeleccionar(modo),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: seleccionada ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              icono,
              color: seleccionada
                  ? TemaService.accentGreen
                  : (esOscuro ? TemaService.darkTextSecondary : TemaService.lightTextSecondary),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: TextStyle(
                      color: esOscuro ? TemaService.darkTextSecondary : TemaService.lightTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (seleccionada)
              const Icon(Icons.check_circle, color: TemaService.accentGreen, size: 20),
          ],
        ),
      ),
    );
  }
}

class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context) {
    final supa = SupabaseService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([TemaService.instance, supa]),
      builder: (context, _) {
        final tema = TemaService.instance;
        final esOscuro = tema.esOscuro;
        final drawerBg = esOscuro ? TemaService.darkCard : TemaService.lightCard;
        final textPrimary = esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary;
        final textSecondary = esOscuro ? TemaService.darkTextSecondary : TemaService.lightTextSecondary;
        final borderActual = esOscuro ? TemaService.darkBorder : TemaService.lightBorder;
        final nombre = supa.nombreConductor;
        final email = supa.emailConductor;

        return Drawer(
          backgroundColor: drawerBg,
          child: Column(
            children: [
              const SizedBox(height: 52),
              Center(
                child: Image.asset(
                  esOscuro
                      ? 'assets/logos/MASGA_LOGO LARGO OSCURO.png'
                      : 'assets/logos/MASGA_LOGO largo blanco.png',
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 36,
                backgroundColor: esOscuro ? TemaService.darkBg : const Color(0xFFE2E8F0),
                child: const Icon(Icons.account_circle, size: 72, color: TemaService.accentGreen),
              ),
              const SizedBox(height: 10),
              Text(
                nombre,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ],
              const SizedBox(height: 20),
              Divider(color: borderActual, height: 1),
              const SizedBox(height: 16),

              // Selector de tema en el Drawer (Claro / Oscuro / Sistema)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEMA VISUAL',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: esOscuro ? TemaService.darkBg : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderActual),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _BotonSegmentoTema(
                              titulo: 'Claro',
                              icono: Icons.light_mode,
                              seleccionado: tema.themeMode == ThemeMode.light,
                              onTap: () => tema.cambiarModo(ThemeMode.light),
                            ),
                          ),
                          Expanded(
                            child: _BotonSegmentoTema(
                              titulo: 'Oscuro',
                              icono: Icons.dark_mode,
                              seleccionado: tema.themeMode == ThemeMode.dark,
                              onTap: () => tema.cambiarModo(ThemeMode.dark),
                            ),
                          ),
                          Expanded(
                            child: _BotonSegmentoTema(
                              titulo: 'Auto',
                              icono: Icons.brightness_auto,
                              seleccionado: tema.themeMode == ThemeMode.system,
                              onTap: () => tema.cambiarModo(ThemeMode.system),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Divider(color: borderActual, height: 1),
              const SizedBox(height: 8),

              ListTile(
                leading: Icon(Icons.notifications_none, color: textPrimary),
                title: Text('Notificaciones', style: TextStyle(fontSize: 16, color: textPrimary)),
                onTap: () {},
              ),
              ListTile(
                leading: Icon(Icons.language, color: textPrimary),
                title: Text('Idioma', style: TextStyle(fontSize: 16, color: textPrimary)),
                onTap: () {},
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: TemaService.accentRed),
                title: const Text('Cerrar sesión', style: TextStyle(fontSize: 16, color: TemaService.accentRed)),
                onTap: () async {
                  await ViajesService.instance.detenerMonitoreo();
                  await SupabaseService.instance.cerrarSesion();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _BotonSegmentoTema extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  const _BotonSegmentoTema({
    required this.titulo,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final esOscuro = TemaService.instance.esOscuro;
    final colorTexto = seleccionado
        ? TemaService.accentGreen
        : (esOscuro ? TemaService.darkTextSecondary : TemaService.lightTextSecondary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado
              ? (esOscuro ? TemaService.darkCard : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: seleccionado
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: esOscuro ? 0.3 : 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 15, color: colorTexto),
            const SizedBox(width: 4),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                color: colorTexto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
