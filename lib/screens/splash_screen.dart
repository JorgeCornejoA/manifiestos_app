import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    // Esperamos a que el primer frame se dibuje para no tener errores de contexto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Escuchamos los cambios en el estado de autenticación.
      _authStateSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        // Si no hay sesión, vamos al login.
        if (session == null) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        } else {
          // Si hay una sesión, vamos a la pantalla principal.
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      });

      // Verificamos si ya existe una sesión al abrir la app.
      final initialSession = Supabase.instance.client.auth.currentSession;
      if (initialSession == null) {
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
         Navigator.of(context).pushReplacementNamed('/home');
      }

    });
  }

  @override
  void dispose() {
    // Es muy importante cancelar la suscripción para evitar fugas de memoria.
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Muestra un indicador de carga mientras se determina a dónde redirigir.
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

