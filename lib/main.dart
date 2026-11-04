import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'login_screen.dart';
import 'pantalla_principal.dart';
import 'permisos_service.dart';
import 'preparativos_screen.dart';
import 'supabase_service.dart';
import 'tema_service.dart';

void main() async {
  // Asegura que los bindings de Flutter estén cargados
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa el servicio de temas (Claro / Oscuro / Sistema)
  await TemaService.instance.inicializar();

  // Inicializa Supabase (Auth + Base de Datos en la nube)
  await SupabaseService.instance.inicializar();

  // Inicializa el SDK de Google Mobile Ads
  await MobileAds.instance.initialize();

  final tieneSesion = SupabaseService.instance.tieneSesionActiva;
  final omitirPreparativos =
      tieneSesion ? await PermisosService.debeOmitirPreparativos() : false;

  runApp(
    MiAppRutas(
      tieneSesion: tieneSesion,
      omitirPreparativos: omitirPreparativos,
    ),
  );
}

class MiAppRutas extends StatelessWidget {
  final bool tieneSesion;
  final bool omitirPreparativos;

  const MiAppRutas({
    super.key,
    this.tieneSesion = false,
    this.omitirPreparativos = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TemaService.instance,
      builder: (context, _) {
        final tema = TemaService.instance;
        final Widget pantallaInicial;
        if (!tieneSesion) {
          pantallaInicial = const LoginScreen();
        } else if (omitirPreparativos) {
          pantallaInicial = const PantallaPrincipal();
        } else {
          pantallaInicial = const PreparativosScreen();
        }

        return MaterialApp(
          title: 'MASGA APP',
          debugShowCheckedModeBanner: false,
          theme: TemaService.temaClaro,
          darkTheme: TemaService.temaOscuro,
          themeMode: tema.themeMode,
          home: pantallaInicial,
        );
      },
    );
  }
}
