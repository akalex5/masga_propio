import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() {
  runApp(const MiAppRutas());
}

class MiAppRutas extends StatelessWidget {
  const MiAppRutas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MASGA APP',
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
