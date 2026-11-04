import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'supabase_service.dart';
import 'tema_service.dart';

class AdGateScreen extends StatefulWidget {
  const AdGateScreen({super.key});

  /// Abre la pantalla para ver 1 anuncio de recompensa y ganar +1 llave en Supabase.
  static Future<bool> obtenerLlave(BuildContext context) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AdGateScreen(),
      ),
    );
    return resultado ?? false;
  }

  /// Alias de compatibilidad
  static Future<bool> abrir(BuildContext context) => obtenerLlave(context);

  @override
  State<AdGateScreen> createState() => _AdGateScreenState();
}

class _AdGateScreenState extends State<AdGateScreen> {
  // ID oficial de prueba de Google AdMob para Rewarded Video en Android
  static const String _rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  RewardedAd? _rewardedAd;
  bool _cargando = true;
  bool _recompensaGanada = false;
  bool _saliendo = false;
  String _estadoTexto = 'Preparando video de recompensa...';

  @override
  void initState() {
    super.initState();
    _cargarAnuncioRecompensa();
  }

  void _cargarAnuncioRecompensa() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted || _saliendo) {
            ad.dispose();
            return;
          }
          _rewardedAd = ad;
          setState(() {
            _cargando = false;
            _estadoTexto = 'Mostrando anuncio...';
          });
          _mostrarAnuncio();
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd falló al cargar: $error');
          if (!mounted) return;
          setState(() {
            _cargando = false;
            _estadoTexto =
                'No se pudo cargar el anuncio en este momento. Intenta de nuevo.';
          });
        },
      ),
    );
  }

  void _mostrarAnuncio() {
    final ad = _rewardedAd;
    if (ad == null) return;
    _rewardedAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        if (!mounted) return;
        if (_recompensaGanada) {
          setState(() {
            _cargando = true;
            _estadoTexto = 'Acreditando tu llave 🔑 en la billetera...';
          });
          final res = await SupabaseService.instance.sumarLlavePorAnuncio();
          if (!mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.mensaje),
              backgroundColor:
                  res.exito ? TemaService.accentGreen : TemaService.accentAmber,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _salir(res.exito);
        } else {
          _salir(false);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _salir(false);
      },
    );

    ad.show(
      onUserEarnedReward: (adWithoutView, reward) {
        _recompensaGanada = true;
      },
    );
  }

  void _salir(bool completado) {
    if (_saliendo) return;
    _saliendo = true;
    if (mounted) Navigator.of(context).pop(completado);
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esOscuro = TemaService.instance.esOscuro;
    final bg = esOscuro ? TemaService.darkBg : TemaService.lightBg;
    final cardBg = esOscuro ? TemaService.darkCard : TemaService.lightCard;
    final border = esOscuro ? TemaService.darkBorder : TemaService.lightBorder;
    final textPrimary =
        esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary;
    final textSecondary = esOscuro
        ? TemaService.darkTextSecondary
        : TemaService.lightTextSecondary;

    final balance = SupabaseService.instance.balanceLlaves;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => _salir(false),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TemaService.accentAmber.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.vpn_key_rounded,
                      size: 36,
                      color: TemaService.accentAmber,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Obtener +1 Llave',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Billetera actual: 🔑 $balance / ${SupabaseService.maxLlaves}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_cargando)
                    const CircularProgressIndicator(
                      color: TemaService.accentGreen,
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _cargando = true;
                          _estadoTexto = 'Reintentando cargar anuncio...';
                        });
                        _cargarAnuncioRecompensa();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TemaService.accentGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _estadoTexto,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
