import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/order_alert_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android system status & navigation bar styling for clean white theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Supabase Client with Service Role Headers to completely bypass RLS
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    headers: {
      'apikey': AppConstants.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
    },
  );

  // Clear any stale cached anonymous auth token from previous sessions
  try {
    if (Supabase.instance.client.auth.currentSession != null) {
      await Supabase.instance.client.auth.signOut();
    }
  } catch (_) {}

  // Background live alerts for new online orders
  OrderAlertService.initMain();

  runApp(const PizzaAdminApp());
}

class PizzaAdminApp extends StatelessWidget {
  const PizzaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sole What Pizza Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppConstants.bgLight,
        primaryColor: AppConstants.primary,
        colorScheme: const ColorScheme.light(
          primary: AppConstants.primary,
          secondary: AppConstants.secondary,
          surface: AppConstants.cardLight,
          onSurface: AppConstants.textDark,
        ),
        fontFamily: GoogleFonts.googleSans().fontFamily,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
