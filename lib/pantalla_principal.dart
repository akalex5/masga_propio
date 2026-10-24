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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
      ),
      drawer: const MenuLateral(),
      body: _pantallas[_indiceActual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) {
          setState(() {
            _indiceActual = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Estadísticas'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate_outlined), label: 'Mis costos'),
        ],
      ),
    );
  }
}

class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const SizedBox(height: 60),
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Icon(Icons.account_circle, size: 80, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 10),
          const Text(
            'Eric',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 30),
          SwitchListTile(
            title: const Text('Modo oscuro', style: TextStyle(fontSize: 18)),
            value: false,
            onChanged: (bool value) {},
          ),
          ListTile(
            leading: const Icon(Icons.notifications, color: Color(0xFF1E3A8A)),
            title: const Text('Notificaciones', style: TextStyle(fontSize: 18)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.language, color: Color(0xFF1E3A8A)),
            title: const Text('Idioma', style: TextStyle(fontSize: 18)),
            onTap: () {},
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF1E3A8A)),
            title: const Text('Cerrar sesión', style: TextStyle(fontSize: 18)),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
