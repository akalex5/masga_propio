import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_gate_service.dart';

class AdGateScreen extends StatefulWidget {
  const AdGateScreen({super.key});

  /// Abre la pantalla. Devuelve true si el usuario vio los anuncios completos.
  static Future<bool> abrir(BuildContext context) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AdGateScreen(),
      ),
    );
    return resultado ?? false;
  }

  @override
  State<AdGateScreen> createState() => _AdGateScreenState();
}

class _AdGateScreenState extends State<AdGateScreen> {
  // ID de bloque de prueba oficial de Google para intersticiales en Android
  static const String _adUnitId = 'ca-app-pub-3940256099942544/1033173712';

  InterstitialAd? _listo; // anuncio ya cargado, esperando su turno
  bool _cargandoSiguiente = false;
  bool _mostrando = false;
  bool _saliendo = false;
  int _vistos = 0;

  @override
  void initState() {
    super.initState();
    _precargar();
  }

  // Carga un anuncio. En cuanto esté listo, se muestra solo si no hay otro en pantalla.
  void _precargar() {
    if (_cargandoSiguiente || _listo != null) return;
    _cargandoSiguiente = true;
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _cargandoSiguiente = false;
          if (!mounted || _saliendo) {
            ad.dispose();
            return;
          }
          _listo = ad;
          if (!_mostrando) _mostrarSiguiente();
        },
        onAdFailedToLoad: (error) {
          _cargandoSiguiente = false;
          debugPrint('Interstitial failed to load: $error');
          _salir(false);
        },
      ),
    );
  }

  void _mostrarSiguiente() {
    final ad = _listo;
    if (ad == null || _mostrando) return;
    _listo = null;
    _mostrando = true;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        // Mientras se ve este anuncio, ya cargamos el siguiente
        if (_vistos + 1 < AdGateService.anunciosRequeridos) _precargar();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _mostrando = false;
        if (!mounted) return;
        setState(() => _vistos++);
        if (_vistos >= AdGateService.anunciosRequeridos) {
          _terminar();
        } else if (_listo != null) {
          _mostrarSiguiente();
        }
        // Si el siguiente aún no carga, onAdLoaded lo mostrará en cuanto esté listo
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: $error');
        ad.dispose();
        _mostrando = false;
        _salir(false);
      },
    );
    ad.show();
  }

  Future<void> _terminar() async {
    if (_saliendo) return;
    await AdGateService.marcarCompletado();
    _salir(true);
  }

  void _salir(bool completado) {
    if (_saliendo) return;
    _saliendo = true;
    if (mounted) Navigator.of(context).pop(completado);
  }

  @override
  void dispose() {
    _listo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = AdGateService.anunciosRequeridos;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _salir(false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_open, size: 72),
              const SizedBox(height: 24),
              const Text(
                'Desbloquea esta función',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Verás $total anuncios seguidos'),
              const SizedBox(height: 24),
              LinearProgressIndicator(value: _vistos / total),
              const SizedBox(height: 12),
              Text('Anuncios vistos: $_vistos de $total'),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Cargando anuncio...'),
            ],
          ),
        ),
      ),
    );
  }
}