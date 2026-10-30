import 'package:flutter/material.dart';
import 'tema_service.dart';
import 'viajes_service.dart';

class MisCostosScreen extends StatefulWidget {
  const MisCostosScreen({super.key});

  @override
  State<MisCostosScreen> createState() => _MisCostosScreenState();
}

class _MisCostosScreenState extends State<MisCostosScreen> {
  late double _gananciaPorKm;
  late double _gastoCombustible;
  late double _precioCombustible;
  late double _tasaImpuestos;
  late double _depreciacionPorKm;

  @override
  void initState() {
    super.initState();
    final s = ViajesService.instance;
    _gananciaPorKm = s.gananciaPorKm;
    _gastoCombustible = s.gastoCombustible;
    _precioCombustible = s.precioCombustible;
    _tasaImpuestos = s.tasaImpuestos;
    _depreciacionPorKm = s.depreciacionPorKm;
  }

  void _cambiarGananciaPorKm(double delta) {
    setState(() {
      final nuevoValor = _gananciaPorKm + delta;
      _gananciaPorKm = nuevoValor < 0 ? 0.0 : nuevoValor;
    });
    _persistirCostosSilencioso();
  }

  Future<void> _persistirCostosSilencioso() async {
    await ViajesService.instance.guardarCostos(
      gananciaPorKm: _gananciaPorKm,
      gastoCombustible: _gastoCombustible,
      precioCombustible: _precioCombustible,
      tasaImpuestos: _tasaImpuestos,
      depreciacionPorKm: _depreciacionPorKm,
    );
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

    final esOscuro = TemaService.instance.esOscuro;
    final dialogBg = esOscuro ? TemaService.darkCard : TemaService.lightCard;
    final textPrimary = esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary;

    final resultado = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: esOscuro ? TemaService.darkBorder : TemaService.lightBorder),
          ),
          title: Text(titulo, style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              suffixText: sufijo,
              filled: true,
              fillColor: esOscuro ? TemaService.darkBg : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TemaService.accentGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final valor = double.tryParse(controller.text.replaceAll(',', '.'));
                Navigator.of(dialogContext).pop(valor);
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (resultado != null && resultado >= 0) {
      setState(() => onGuardar(resultado));
      await _persistirCostosSilencioso();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TemaService.instance,
      builder: (context, _) {
        final esOscuro = TemaService.instance.esOscuro;
        final bgScreen = esOscuro ? TemaService.darkBg : TemaService.lightBg;
        final cardBg = esOscuro ? TemaService.darkCard : TemaService.lightCard;
        final cardBorder = esOscuro ? TemaService.darkBorder : TemaService.lightBorder;
        final textPrimary = esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary;
        final textSecondary = esOscuro ? TemaService.darkTextSecondary : TemaService.lightTextSecondary;

        return Scaffold(
          backgroundColor: bgScreen,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera
                Text(
                  'PARÁMETROS',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mis Costos Operativos',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),

                const SizedBox(height: 18),

                // Tarjeta Principal: Meta de Ganancia por Km (Semáforo del popup)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      if (!esOscuro)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'META MÍNIMA POR KM',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Filtro para marcar "Conviene"',
                                style: TextStyle(color: textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: TemaService.accentGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Activo',
                              style: TextStyle(
                                color: TemaService.accentGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '\$${_gananciaPorKm.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: TemaService.accentGreen,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/ km',
                            style: TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Controles de ajuste rápido (+ / -)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _cambiarGananciaPorKm(-1.0),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: cardBorder),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('- \$1.00', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _mostrarDialogoEdicion(
                              titulo: 'Meta de ganancia por km',
                              sufijo: 'MXN/km',
                              valorActual: _gananciaPorKm,
                              onGuardar: (v) => _gananciaPorKm = v,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            color: textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _cambiarGananciaPorKm(1.0),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TemaService.accentGreen,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('+ \$1.00', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'COSTOS DE VEHÍCULO Y FISCALES',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // Lista de tarjetas de costos
                _ItemCostoTile(
                  titulo: 'Rendimiento de Gasolina',
                  subtitulo: 'Kilómetros promedio por litro',
                  valor: '${_gastoCombustible.toStringAsFixed(1)} km/L',
                  icono: Icons.local_gas_station_outlined,
                  colorIcono: const Color(0xFF0284C7),
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  esOscuro: esOscuro,
                  onTap: () => _mostrarDialogoEdicion(
                    titulo: 'Rendimiento de combustible',
                    sufijo: 'km/L',
                    valorActual: _gastoCombustible,
                    onGuardar: (v) => _gastoCombustible = v,
                  ),
                ),

                const SizedBox(height: 10),

                _ItemCostoTile(
                  titulo: 'Precio del Combustible',
                  subtitulo: 'Costo por litro de gasolina o gas',
                  valor: '\$${_precioCombustible.toStringAsFixed(2)} /L',
                  icono: Icons.attach_money,
                  colorIcono: const Color(0xFF10B981),
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  esOscuro: esOscuro,
                  onTap: () => _mostrarDialogoEdicion(
                    titulo: 'Precio por litro',
                    sufijo: 'MXN/L',
                    valorActual: _precioCombustible,
                    onGuardar: (v) => _precioCombustible = v,
                  ),
                ),

                const SizedBox(height: 10),

                _ItemCostoTile(
                  titulo: 'Tasa de Impuestos Retenidos',
                  subtitulo: 'ISR + IVA aproximado sobre viajes',
                  valor: '${_tasaImpuestos.toStringAsFixed(1)} %',
                  icono: Icons.account_balance_outlined,
                  colorIcono: const Color(0xFF8B5CF6),
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  esOscuro: esOscuro,
                  onTap: () => _mostrarDialogoEdicion(
                    titulo: 'Tasa de impuestos',
                    sufijo: '%',
                    valorActual: _tasaImpuestos,
                    onGuardar: (v) => _tasaImpuestos = v,
                  ),
                ),

                const SizedBox(height: 10),

                _ItemCostoTile(
                  titulo: 'Depreciación y Mantenimiento',
                  subtitulo: 'Llantas, aceite, frenos y desgaste',
                  valor: '\$${_depreciacionPorKm.toStringAsFixed(2)} /km',
                  icono: Icons.build_outlined,
                  colorIcono: const Color(0xFFFF7A00),
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  esOscuro: esOscuro,
                  onTap: () => _mostrarDialogoEdicion(
                    titulo: 'Depreciación por km',
                    sufijo: 'MXN/km',
                    valorActual: _depreciacionPorKm,
                    onGuardar: (v) => _depreciacionPorKm = v,
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ItemCostoTile extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String valor;
  final IconData icono;
  final Color colorIcono;
  final Color cardBg;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final bool esOscuro;
  final VoidCallback onTap;

  const _ItemCostoTile({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.icono,
    required this.colorIcono,
    required this.cardBg,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.esOscuro,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
          boxShadow: [
            if (!esOscuro)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorIcono.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: colorIcono, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  valor,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: textSecondary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
