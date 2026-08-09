import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/stellar_service.dart';
import 'screens/landing_screen.dart';

void main() {
  runApp(const InFlowMobileApp());
}

class InFlowMobileApp extends StatelessWidget {
  const InFlowMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final stellarService = StellarService();

    return MaterialApp(
      title: 'inFlow Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05050A),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: LandingScreen(stellarService: stellarService),
    );
  }
}
