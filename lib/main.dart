import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'tema_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  // Asegura que los bindings de Flutter estén cargados
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa el servicio de temas (Claro / Oscuro / Sistema)
  await TemaService.instance.inicializar();

  // Inicializa el SDK de Google Mobile Ads
  await MobileAds.instance.initialize();

  runApp(const MiAppRutas());
}

class MiAppRutas extends StatelessWidget {
  const MiAppRutas({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TemaService.instance,
      builder: (context, _) {
        final tema = TemaService.instance;
        return MaterialApp(
          title: 'MASGA APP',
          debugShowCheckedModeBanner: false,
          theme: TemaService.temaClaro,
          darkTheme: TemaService.temaOscuro,
          themeMode: tema.themeMode,
          home: const LoginScreen(),
        );
      },
    );
  }
}
