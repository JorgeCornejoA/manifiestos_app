import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <--- 1. IMPORTANTE: Agrega esta librería
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:manifiestos_app/features/clients/clients_screen.dart';
import 'package:manifiestos_app/features/manifest/manifest_form_screen.dart';
import 'package:manifiestos_app/features/manifest/manifests_list_screen.dart';
import 'package:manifiestos_app/screens/home_screen.dart';
import 'package:manifiestos_app/screens/login_screen.dart';
import 'package:manifiestos_app/screens/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manifiestos_app/features/operators/operators_screen.dart';
import 'package:manifiestos_app/features/operators/operator_form_screen.dart';
import 'package:manifiestos_app/models/operator.dart';
import 'package:manifiestos_app/features/clients/client_form_screen.dart';
import 'package:manifiestos_app/models/client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- 2. CÓDIGO PARA BLOQUEAR LA ROTACIÓN ---
  // Esto obliga a la app a mantenerse siempre en vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // -------------------------------------------

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
    const primaryGreen = Color(0xFF2E7D32);
    const secondaryGreen = Color(0xFF43A047);
    const lightGreen = Color(0xFFE8F5E9);

    return MaterialApp(
      title: 'Manifiestos App',
      debugShowCheckedModeBanner: false,
      
      theme: ThemeData(
        useMaterial3: true,
        
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          primary: primaryGreen,
          secondary: secondaryGreen,
          surface: Colors.white,
          background: Colors.white,
        ),

        scaffoldBackgroundColor: Colors.white,

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: primaryGreen,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: primaryGreen,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: primaryGreen),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightGreen.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryGreen, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey[700]),
          prefixIconColor: primaryGreen,
          suffixIconColor: primaryGreen,
        ),
      ),

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
      ],

      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/manifest-form': (context) => const ManifestFormScreen(),
        '/clients': (context) => const ClientsScreen(),
        
        '/client-form': (context) {
          final client = ModalRoute.of(context)!.settings.arguments as Client?;
          return ClientFormScreen(client: client);
        },

        '/operators': (context) => const OperatorsScreen(),
        '/operator-form': (context) {
          final operator = ModalRoute.of(context)!.settings.arguments as Operator?;
          return OperatorFormScreen(operator: operator);
        },
        
        '/manifests-list': (context) => const ManifestsListScreen(),
      },
    );
  }
}