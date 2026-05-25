import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'services/firebase_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/patient_intake_screen.dart';
import 'screens/patient_dossier_screen.dart';
import 'screens/no_internet_screen.dart';

void main() async {
  // Ensure widget binding is active before running platform plugins
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try initializing Firebase in the background, with automatic silent fallback to local mock database
  FirebaseService.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkSession()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'WeAssist Caretaker',
            theme: AppTheme.darkTheme,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              if (!auth.isOnline) {
                return const NoInternetScreen();
              }
              return child ?? const SizedBox.shrink();
            },
            // Direct to dashboard if already authenticated
            home: !auth.isInitialized
                ? const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                    ),
                  )
                : (auth.currentUser != null
                    ? const DashboardScreen()
                    : const LoginScreen()),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/intake': (context) => const PatientIntakeScreen(),
              '/dossier': (context) => const PatientDossierScreen(),
            },
          );
        },
      ),
    );
  }
}
