import 'package:flutter/material.dart';
import 'estadisticas_screen.dart';
import 'historial_screen.dart';
import 'inicio_screen.dart';
import 'login_screen.dart';
import 'mis_costos_screen.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const MenuLateral(),
      body: _pantallas[_indiceActual],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF30363D), width: 0.5)),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF161B22),
          currentIndex: _indiceActual,
          onTap: (index) {
            setState(() {
              _indiceActual = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF10B981),
          unselectedItemColor: const Color(0xFF8B949E),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Estadísticas'),
            BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Costos'),
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
    return Drawer(
      backgroundColor: const Color(0xFF161B22),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFF0D1117),
            child: Icon(Icons.account_circle, size: 80, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 10),
          const Text(
            'Eric',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 30),
          SwitchListTile(
            title: const Text('Modo oscuro', style: TextStyle(fontSize: 18, color: Colors.white)),
            value: true,
            activeColor: const Color(0xFF10B981),
            onChanged: (bool value) {},
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none, color: Colors.white),
            title: const Text('Notificaciones', style: TextStyle(fontSize: 18, color: Colors.white)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.white),
            title: const Text('Idioma', style: TextStyle(fontSize: 18, color: Colors.white)),
            onTap: () {},
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            title: const Text('Cerrar sesión', style: TextStyle(fontSize: 18, color: Color(0xFFEF4444))),
            onTap: () async {
              await ViajesService.instance.detenerMonitoreo();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
