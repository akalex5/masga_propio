import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  // Asegura que los bindings de Flutter estén cargados
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa el SDK de Google Mobile Ads
  await MobileAds.instance.initialize();

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