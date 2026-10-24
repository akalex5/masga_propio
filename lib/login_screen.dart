import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _ocultarContrasena = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                        // Rectángulo gris superior (Placeholder para logo)
                        Container(
                          height: 52,
                          width: 115,
                          color: Colors.grey.shade200,
                        ),
                        const SizedBox(height: 16),

                        // Título y subtítulo
                        const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828), // Azul muy oscuro/casi negro
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '¡Hola de nuevo! Ingresa para continuar.',
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                        const Spacer(),
                        const SizedBox(height: 12),

                        // Fila de Correo electrónico y Usar teléfono
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Correo electrónico',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                                style: TextStyle(fontSize: 14, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Campo de texto: Correo
                        TextField(
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'correo@ejemplo.com',
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF8B98A5)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            filled: true,
                            fillColor: const Color(0xFFF3F4F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Etiqueta Contraseña
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Contraseña',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Campo de texto: Contraseña
                        TextField(
                          obscureText: _ocultarContrasena,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8B98A5)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _ocultarContrasena ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _ocultarContrasena = !_ocultarContrasena;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF3F4F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
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
                              style: TextStyle(color: Color(0xFF2563EB), fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Botón principal de Iniciar sesión
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const PantallaPrincipal(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB), // Azul del botón
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Iniciar sesión',
                              style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 12),

                        // Separador "O inicia sesión con"
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'O inicia sesión con',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Botones de inicio de sesión alternativo (Google y Teléfono celular)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSocialButton(
                              child: const _GoogleLogo(size: 26),
                              onTap: () {},
                            ),
                            const SizedBox(width: 24),
                            _buildSocialButton(
                              child: const Icon(Icons.smartphone, color: Color(0xFF2563EB), size: 28),
                              onTap: () {},
                            ),
                          ],
                        ),
                        const Spacer(),
                        const SizedBox(height: 12),

                        // Texto Regístrate
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '¿No tienes una cuenta? ',
                              style: TextStyle(color: Colors.black87),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                'Regístrate',
                                style: TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold,
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
  }

  // Widget personalizado para los botones circulares con sombra
  Widget _buildSocialButton({required Widget child, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
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
              width: 30,
              height: 30,
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

    // Rojo (parte superior)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, degToRad(215), degToRad(100), false, paint);

    // Amarillo (parte izquierda)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, degToRad(145), degToRad(70), false, paint);

    // Verde (parte inferior)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, degToRad(45), degToRad(100), false, paint);

    // Azul (arco inferior derecho + barra horizontal)
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
