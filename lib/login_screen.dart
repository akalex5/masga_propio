import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_principal.dart';
import 'permisos_service.dart';
import 'preparativos_screen.dart';
import 'supabase_service.dart';
import 'tema_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _ocultarContrasena = true;
  bool _verificandoAcceso = false;
  bool _modoRegistro = false;

  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Si regresa de un login con Google OAuth, navegar automáticamente
    _authSub =
        SupabaseService.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _navegarSiguientePantalla();
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _navegarSiguientePantalla() async {
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

  Future<void> _enviarFormulario() async {
    if (_verificandoAcceso) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final nombre = _nombreController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _mostrarMensaje('Ingresa un correo electrónico válido.', esError: true);
      return;
    }
    if (password.length < 6) {
      _mostrarMensaje(
        'La contraseña debe tener al menos 6 caracteres.',
        esError: true,
      );
      return;
    }

    setState(() => _verificandoAcceso = true);

    final ResultadoOperacion res;
    if (_modoRegistro) {
      res = await SupabaseService.instance.registrarConCorreo(
        email: email,
        password: password,
        nombre: nombre,
      );
    } else {
      res = await SupabaseService.instance.iniciarSesionConCorreo(
        email: email,
        password: password,
      );
    }

    if (!mounted) return;
    setState(() => _verificandoAcceso = false);

    _mostrarMensaje(res.mensaje, esError: !res.exito);

    if (res.exito && SupabaseService.instance.tieneSesionActiva) {
      await _navegarSiguientePantalla();
    } else if (res.exito && _modoRegistro) {
      // Si se creó la cuenta pero requiere confirmar correo, pasamos a modo login
      setState(() => _modoRegistro = false);
    }
  }

  Future<void> _iniciarConGoogle() async {
    if (_verificandoAcceso) return;
    setState(() => _verificandoAcceso = true);

    final res = await SupabaseService.instance.iniciarSesionConGoogle();
    if (!mounted) return;
    setState(() => _verificandoAcceso = false);

    if (!res.exito) {
      _mostrarMensaje(res.mensaje, esError: true);
    }
  }

  Future<void> _mostrarDialogoRecuperarPassword() async {
    final esOscuro = TemaService.instance.esOscuro;
    final dialogBg = esOscuro ? TemaService.darkCard : TemaService.lightCard;
    final border = esOscuro ? TemaService.darkBorder : TemaService.lightBorder;
    final textPrimary =
        esOscuro ? TemaService.darkTextPrimary : TemaService.lightTextPrimary;
    final textSecondary = esOscuro
        ? TemaService.darkTextSecondary
        : TemaService.lightTextSecondary;

    final ctrl = TextEditingController(text: _emailController.text.trim());

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: border),
          ),
          title: Text(
            'Recuperar contraseña',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Te enviaremos un enlace a tu correo para restablecer tu contraseña.',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'correo@ejemplo.com',
                  hintStyle:
                      TextStyle(color: textSecondary.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.mail_outline, color: textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: TemaService.accentGreen,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final correo = ctrl.text.trim();
                Navigator.pop(ctx);
                if (correo.isEmpty || !correo.contains('@')) {
                  _mostrarMensaje('Ingresa un correo válido.', esError: true);
                  return;
                }
                final res =
                    await SupabaseService.instance.recuperarContrasena(correo);
                if (!mounted) return;
                _mostrarMensaje(res.mensaje, esError: !res.exito);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TemaService.accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Enviar enlace'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarMensaje(String texto, {required bool esError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor:
            esError ? TemaService.accentRed : TemaService.accentGreen,
        behavior: SnackBarBehavior.floating,
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
        final cardBorder =
            esOscuro ? TemaService.darkBorder : TemaService.lightBorder;
        final textPrimary = esOscuro
            ? TemaService.darkTextPrimary
            : TemaService.lightTextPrimary;
        final textSecondary = esOscuro
            ? TemaService.darkTextSecondary
            : TemaService.lightTextSecondary;
        final inputFill =
            esOscuro ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9);

        return Scaffold(
          backgroundColor: bgScreen,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 8),

                            // Logo oficial MasGa
                            Image.asset(
                              esOscuro
                                  ? 'assets/logos/MASGA_LOGO LARGO OSCURO.png'
                                  : 'assets/logos/MASGA_LOGO largo blanco.png',
                              height: 54,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 20),

                            // Título y subtítulo dinámicos
                            Text(
                              _modoRegistro ? 'Crear cuenta' : 'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _modoRegistro
                                  ? 'Regístrate para guardar tus llaves y turnos.'
                                  : '¡Hola de nuevo! Ingresa para continuar.',
                              style:
                                  TextStyle(fontSize: 15, color: textSecondary),
                            ),
                            const Spacer(),
                            const SizedBox(height: 12),

                            // Campo Nombre (solo en modo Registro)
                            if (_modoRegistro) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Tu nombre',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _nombreController,
                                textCapitalization: TextCapitalization.words,
                                style: TextStyle(color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Ej. Carlos Hernández',
                                  hintStyle: TextStyle(
                                      color:
                                          textSecondary.withValues(alpha: 0.7)),
                                  prefixIcon: Icon(Icons.person_outline,
                                      color: textSecondary),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 16),
                                  filled: true,
                                  fillColor: inputFill,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: cardBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: TemaService.accentGreen,
                                        width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Etiqueta Correo electrónico
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Correo electrónico',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Campo de texto: Correo
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(color: textPrimary),
                              decoration: InputDecoration(
                                hintText: 'correo@ejemplo.com',
                                hintStyle: TextStyle(
                                    color:
                                        textSecondary.withValues(alpha: 0.7)),
                                prefixIcon: Icon(Icons.mail_outline,
                                    color: textSecondary),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                filled: true,
                                fillColor: inputFill,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: TemaService.accentGreen,
                                      width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Etiqueta Contraseña
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Contraseña',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Campo de texto: Contraseña
                            TextField(
                              controller: _passwordController,
                              obscureText: _ocultarContrasena,
                              onSubmitted: (_) => _enviarFormulario(),
                              style: TextStyle(color: textPrimary),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                hintStyle: TextStyle(
                                    color:
                                        textSecondary.withValues(alpha: 0.7)),
                                prefixIcon: Icon(Icons.lock_outline,
                                    color: textSecondary),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _ocultarContrasena
                                        ? Icons.visibility_off
                                        : Icons.visibility,
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
                                  borderSide: const BorderSide(
                                      color: TemaService.accentGreen,
                                      width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Botón Olvidaste tu contraseña
                            if (!_modoRegistro)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _mostrarDialogoRecuperarPassword,
                                  style: TextButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: TextStyle(
                                      color: TemaService.accentGreen,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),

                            // Botón principal de Iniciar sesión / Crear cuenta
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _verificandoAcceso
                                    ? null
                                    : _enviarFormulario,
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
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        _modoRegistro
                                            ? 'Crear cuenta'
                                            : 'Iniciar sesión',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 14),

                            // Separador "O continúa con"
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: cardBorder, thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Text(
                                    'O continúa con Google',
                                    style: TextStyle(
                                        color: textSecondary, fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: cardBorder, thickness: 1)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Botón de inicio de sesión con Google
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _verificandoAcceso
                                    ? null
                                    : _iniciarConGoogle,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: cardBg,
                                  side: BorderSide(color: cardBorder),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const _GoogleLogo(size: 20),
                                label: Text(
                                  'Continuar con Google',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 14),

                            // Alternar entre Iniciar sesión y Regístrate
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _modoRegistro
                                      ? '¿Ya tienes una cuenta? '
                                      : '¿No tienes una cuenta? ',
                                  style: TextStyle(
                                      color: textSecondary, fontSize: 14),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _modoRegistro = !_modoRegistro;
                                    });
                                  },
                                  child: Text(
                                    _modoRegistro
                                        ? 'Inicia sesión'
                                        : 'Regístrate',
                                    style: const TextStyle(
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
