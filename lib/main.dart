import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() {
  runApp(const MiAppRutas());
}

class MiAppRutas extends StatelessWidget {
  const MiAppRutas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tracker de Viajes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1E3A8A),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceActual = 0;

  final List<Widget> _pantallas = [
    const InicioScreen(),
    const HistorialScreen(),
    const EstadisticasScreen(),
    const MisCostosScreen(),
  ];

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
            onTap: () {},
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '¡Hola, Eric! 👋',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ganancia de hoy: \$185.00 MXN',
            style: TextStyle(fontSize: 20, color: Colors.teal, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 80),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(80),
              elevation: 10,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, size: 40, color: Colors.white),
                SizedBox(width: 8),
                Text('Iniciar', style: TextStyle(fontSize: 32, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
              ),
              Text('Hoy ▼', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Total: 1 viaje | \$78.00 MXN',
            style: TextStyle(fontSize: 18, color: Colors.teal, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF1E3A8A)),
              boxShadow: [
                BoxShadow(color: Colors.grey.withValues(alpha: 0.2), blurRadius: 5, spreadRadius: 1),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hoy, 02:30 PM', style: TextStyle(fontSize: 16)),
                Text('+\$78.00 MXN', style: TextStyle(fontSize: 16, color: Colors.teal, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EstadisticasScreen extends StatelessWidget {
  const EstadisticasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Gráficos y Estadísticas Próximamente', style: TextStyle(fontSize: 18, color: Colors.grey)),
    );
  }
}

class MisCostosScreen extends StatefulWidget {
  const MisCostosScreen({super.key});

  @override
  State<MisCostosScreen> createState() => _MisCostosScreenState();
}

class _MisCostosScreenState extends State<MisCostosScreen> {
  double _gananciaPorKm = 10.00;
  double _gastoCombustible = 14.0;
  double _tasaImpuestos = 8.0;
  double _depreciacionPorKm = 2.50;

  void _cambiarGananciaPorKm(double delta) {
    setState(() {
      final nuevoValor = _gananciaPorKm + delta;
      _gananciaPorKm = nuevoValor < 0 ? 0.0 : nuevoValor;
    });
  }

  Future<void> _mostrarDialogoEdicion({
    required String titulo,
    required String sufijo,
    required double valorActual,
    required ValueChanged<double> onGuardar,
  }) async {
    final controller = TextEditingController(
      text: valorActual.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), ''),
    );

    final resultado = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            titulo,
            style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              suffixText: sufijo,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (texto) {
              final valor = double.tryParse(texto.replaceAll(',', '.'));
              if (valor != null && valor >= 0) {
                Navigator.of(dialogContext).pop(valor);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final valor = double.tryParse(controller.text.replaceAll(',', '.'));
                if (valor != null && valor >= 0) {
                  Navigator.of(dialogContext).pop(valor);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
              ),
              child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (resultado != null) {
      setState(() {
        onGuardar(resultado);
      });
    }
  }

  String _formatearCombustible(double valor) {
    final texto = valor % 1 == 0 ? valor.toInt().toString() : valor.toStringAsFixed(1);
    return '$texto Km/L';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mis costos',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text('Ganancia por Kilómetro', style: TextStyle(fontSize: 16, color: Colors.blueGrey)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildCirculoBoton(
                                Icons.remove,
                                onPressed: () => _cambiarGananciaPorKm(-0.50),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _mostrarDialogoEdicion(
                                  titulo: 'Ganancia por Kilómetro',
                                  sufijo: 'MXN / km',
                                  valorActual: _gananciaPorKm,
                                  onGuardar: (valor) => _gananciaPorKm = valor,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                  child: Text(
                                    '\$${_gananciaPorKm.toStringAsFixed(2)} MXN / km',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              _buildCirculoBoton(
                                Icons.add,
                                onPressed: () => _cambiarGananciaPorKm(0.50),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildFilaCosto(
                      Icons.local_gas_station,
                      'Gasto de combustible',
                      _formatearCombustible(_gastoCombustible),
                      onTap: () => _mostrarDialogoEdicion(
                        titulo: 'Gasto de combustible',
                        sufijo: 'Km/L',
                        valorActual: _gastoCombustible,
                        onGuardar: (valor) => _gastoCombustible = valor,
                      ),
                    ),
                    const Divider(),
                    _buildFilaCosto(
                      Icons.percent,
                      'Tasa fiscal / Impuestos',
                      '${_tasaImpuestos.toStringAsFixed(1)}%',
                      onTap: () => _mostrarDialogoEdicion(
                        titulo: 'Tasa fiscal / Impuestos',
                        sufijo: '%',
                        valorActual: _tasaImpuestos,
                        onGuardar: (valor) => _tasaImpuestos = valor,
                      ),
                    ),
                    const Divider(),
                    _buildFilaCosto(
                      Icons.directions_car,
                      'Depreciación del vehículo',
                      'Por km:\n\$${_depreciacionPorKm.toStringAsFixed(2)} MXN',
                      onTap: () => _mostrarDialogoEdicion(
                        titulo: 'Depreciación por km',
                        sufijo: 'MXN / km',
                        valorActual: _depreciacionPorKm,
                        onGuardar: (valor) => _depreciacionPorKm = valor,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Costos guardados correctamente'),
                              backgroundColor: Color(0xFF1E3A8A),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Guardar cambios', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCirculoBoton(IconData icon, {required VoidCallback onPressed}) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildFilaCosto(
    IconData icon,
    String titulo,
    String valor, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1E3A8A), size: 28),
            const SizedBox(width: 15),
            Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16))),
            Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(width: 10),
            const Icon(Icons.edit, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}