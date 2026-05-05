import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/water_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/ai_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void backgroundEntry() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("[NATIVE-SYNC] Background entry triggered");
  try {
    // Load environment variables for AI service
    await dotenv.load(fileName: ".env");

    // Initialize Firebase for background cloud operations
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await AiService.init();

    final provider = WaterProvider();
    await provider.init(); // This includes auto-refresh check
    
    print("[NATIVE-SYNC] Maintenance completed successfully.");
  } catch (e) {
    print("[NATIVE-SYNC] Task failed: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Force Portrait Mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  final waterProvider = WaterProvider();
  await waterProvider.init();
  await AiService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: waterProvider),
      ],
      child: const HydroSyncApp(),
    ),
  );
}

class HydroSyncApp extends StatelessWidget {
  const HydroSyncApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydroSync',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [observer],
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00D2FF),
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D2FF),
          secondary: Color(0xFF3A7BD5),
        ),
      ),
      home: Provider.of<WaterProvider>(context, listen: false).settings?.isOnboarded ?? false
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}
