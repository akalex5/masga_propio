import 'package:flutter/material.dart';
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
      await _persistirCostosSilencioso();
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
                    const SizedBox(height: 24),
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
                      Icons.attach_money,
                      'Precio de gasolina',
                      '\$${_precioCombustible.toStringAsFixed(2)} / L',
                      onTap: () => _mostrarDialogoEdicion(
                        titulo: 'Precio por litro de gasolina',
                        sufijo: 'MXN / L',
                        valorActual: _precioCombustible,
                        onGuardar: (valor) => _precioCombustible = valor,
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
                        onPressed: () async {
                          await _persistirCostosSilencioso();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Costos guardados y sincronizados con el monitor de viajes'),
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
