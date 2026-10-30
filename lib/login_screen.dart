import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pantalla_principal.dart';
import 'permisos_service.dart';
import 'preparativos_screen.dart';
import 'tema_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _ocultarContrasena = true;
  bool _verificandoAcceso = false;

  Future<void> _iniciarSesion() async {
    if (_verificandoAcceso) return;
    setState(() => _verificandoAcceso = true);

    final omitirPreparativos = await PermisosService.debeOmitirPreparativos();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => omitirPreparativos
            ? const PantallaPrincipal()
            : const PreparativosScreen(),
      ),
    );
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
        final inputFill = esOscuro ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9);

        return Scaffold(
          backgroundColor: bgScreen,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 8),

                            // Logo o badge superior MasGa
                            Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: TemaService.accentGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'MASGA',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Título y subtítulo
                            Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '¡Hola de nuevo! Ingresa para continuar.',
                              style: TextStyle(fontSize: 15, color: textSecondary),
                            ),
                            const Spacer(),
                            const SizedBox(height: 12),

                            // Fila de Correo electrónico y Usar teléfono
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Correo electrónico',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                                ),
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Usar teléfono',
                                    style: TextStyle(fontSize: 13, color: TemaService.accentGreen, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Campo de texto: Correo
                            TextField(
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(color: textPrimary),
                              decoration: InputDecoration(
                                hintText: 'correo@ejemplo.com',
                                hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
                                prefixIcon: Icon(Icons.mail_outline, color: textSecondary),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                filled: true,
                                fillColor: inputFill,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: TemaService.accentGreen, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Etiqueta Contraseña
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Contraseña',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Campo de texto: Contraseña
                            TextField(
                              obscureText: _ocultarContrasena,
                              style: TextStyle(color: textPrimary),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
                                prefixIcon: Icon(Icons.lock_outline, color: textSecondary),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _ocultarContrasena ? Icons.visibility_off : Icons.visibility,
                                    color: textSecondary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _ocultarContrasena = !_ocultarContrasena;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: inputFill,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: TemaService.accentGreen, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Botón Olvidaste tu contraseña
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(color: TemaService.accentGreen, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Botón principal de Iniciar sesión
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _verificandoAcceso ? null : _iniciarSesion,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TemaService.accentGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                  elevation: esOscuro ? 0 : 2,
                                ),
                                child: _verificandoAcceso
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text(
                                        'Iniciar sesión',
                                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 14),

                            // Separador "O inicia sesión con"
                            Row(
                              children: [
                                Expanded(child: Divider(color: cardBorder, thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'O inicia sesión con',
                                    style: TextStyle(color: textSecondary, fontSize: 12),
                                  ),
                                ),
                                Expanded(child: Divider(color: cardBorder, thickness: 1)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Botones de inicio de sesión alternativo (Google y Teléfono)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSocialButton(
                                  cardBg: cardBg,
                                  cardBorder: cardBorder,
                                  child: const _GoogleLogo(size: 24),
                                  onTap: () {},
                                ),
                                const SizedBox(width: 20),
                                _buildSocialButton(
                                  cardBg: cardBg,
                                  cardBorder: cardBorder,
                                  child: const Icon(Icons.smartphone, color: TemaService.accentGreen, size: 24),
                                  onTap: () {},
                                ),
                              ],
                            ),
                            const Spacer(),
                            const SizedBox(height: 14),

                            // Texto Regístrate
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '¿No tienes una cuenta? ',
                                  style: TextStyle(color: textSecondary, fontSize: 14),
                                ),
                                GestureDetector(
                                  onTap: () {},
                                  child: const Text(
                                    'Regístrate',
                                    style: TextStyle(
                                      color: TemaService.accentGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialButton({
    required Widget child,
    required VoidCallback onTap,
    required Color cardBg,
    required Color cardBorder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        shape: BoxShape.circle,
        border: Border.all(color: cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: 28,
              height: 28,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  final double size;

  const _GoogleLogo({this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.20;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double degToRad(double deg) => deg * (math.pi / 180.0);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, degToRad(215), degToRad(100), false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, degToRad(145), degToRad(70), false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, degToRad(45), degToRad(100), false, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, degToRad(-12), degToRad(57), false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - strokeWidth * 0.45,
        size.width * 0.96,
        center.dy + strokeWidth * 0.45,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
