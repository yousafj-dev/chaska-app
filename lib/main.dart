import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase is optional at runtime: the app still opens (with friendly
  // offline messages) when init fails, e.g. before google-services.json
  // is added. Importing firebase_core is safe; only initializeApp()
  // throws when the platform config is missing, and we catch it here.
  try {
    await Firebase.initializeApp();
    AuthService.firebaseReady = true;
    debugPrint('Chaska: Firebase ready');
  } catch (e) {
    debugPrint('Chaska: Firebase init failed (offline mode): $e');
    AuthService.firebaseReady = false;
  }
  runApp(const ChaskaApp());
}

class ChaskaApp extends StatelessWidget {
  const ChaskaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService.instance..init(),
      child: MaterialApp(
        title: 'Chaska',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const SplashScreen(),
      ),
    );
  }
}
