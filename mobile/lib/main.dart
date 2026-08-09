import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/stellar_service.dart';
import 'services/storage_service.dart';
import 'screens/landing_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const InFlowMobileApp());
}

class InFlowMobileApp extends StatelessWidget {
  const InFlowMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(
        stellarService: StellarService(),
        storageService: StorageService(),
      )..initialize(),
      child: MaterialApp(
        title: 'inFlow — Stellar Salary Streaming',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF05050A),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFFF59E0B),
            secondary: const Color(0xFF00D37F),
            surface: const Color(0xFF0C0C14),
          ),
          textTheme: GoogleFonts.plusJakartaSansTextTheme(
            ThemeData.dark().textTheme,
          ),
          useMaterial3: true,
        ),
        home: const _RootScreen(),
      ),
    );
  }
}

/// Reads AppProvider on start — routes to Dashboard if a session
/// was restored from secure storage, otherwise shows LandingScreen.
class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (provider.isAuthenticated) {
      return const DashboardScreen();
    }
    return const LandingScreen();
  }
}
