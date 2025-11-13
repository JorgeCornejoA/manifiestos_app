import 'package:flutter/material.dart';
import 'package:manifiestos_app/features/clients/clients_screen.dart';
import 'package:manifiestos_app/features/manifest/manifest_form_screen.dart';
import 'package:manifiestos_app/features/manifest/manifests_list_screen.dart';
import 'package:manifiestos_app/screens/home_screen.dart';
import 'package:manifiestos_app/screens/login_screen.dart';
import 'package:manifiestos_app/screens/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://mnpffwxnrydzahnfivgv.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ucGZmd3hucnlkemFobmZpdmd2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc3ODUyNjMsImV4cCI6MjA3MzM2MTI2M30.1jiE_dZlSBrlWMA0JIwhaOMbiyoZljgIQlfMjohNZCY';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manifiestos App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/manifest-form': (context) => const ManifestFormScreen(),
        '/clients': (context) => const ClientsScreen(),
        '/manifests-list': (context) => const ManifestsListScreen(),
      },
    );
  }
}