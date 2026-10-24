import 'package:flutter/material.dart';

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
