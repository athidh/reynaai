// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'widgets/app_shell.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppState();
  
  // Try to load session with timeout to prevent startup hang
  try {
    await appState.loadSession().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('[Startup] Session load timed out - continuing anyway');
      },
    );
  } catch (e) {
    debugPrint('[Startup] Session load failed: $e - continuing anyway');
  }

  // Check backend connectivity (non-blocking)
  _checkBackendConnectivity();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const ReynaApp(),
    ),
  );
}

/// Check backend connectivity in background (non-blocking)
void _checkBackendConnectivity() async {
  try {
    final isAlive = await ApiService.isBackendAlive().timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
    
    if (isAlive) {
      debugPrint('[Startup] ✅ Backend is reachable at ${ApiService.baseUrl}');
    } else {
      debugPrint('[Startup] ⚠️  Backend not reachable - app will work in offline mode');
    }
  } catch (e) {
    debugPrint('[Startup] ⚠️  Backend check failed: $e - app will work in offline mode');
  }
}

class ReynaApp extends StatelessWidget {
  const ReynaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return MaterialApp(
      title: 'REYNA AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: state.isLoggedIn ? '/app' : '/',
      routes: {
        '/': (_) => const LandingScreen(),
        '/landing': (_) => const LandingScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/app': (_) => const AppShell(),
      },
    );
  }
}
