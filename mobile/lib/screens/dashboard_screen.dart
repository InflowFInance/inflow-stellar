import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/stellar_service.dart';
import '../widgets/live_ticker.dart';

class DashboardScreen extends StatelessWidget {
  final StellarService stellarService;

  const DashboardScreen({required this.stellarService, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C14),
        title: Text(
          'inFlow Dashboard',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8A8FA8)),
            onPressed: () async {
              await stellarService.logout();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            Text(
              'Connected Account',
              style: GoogleFonts.inter(color: const Color(0xFF8A8FA8), fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              stellarService.publicKey ?? 'Not Connected',
              style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1C1C2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('USDC Stream Rate', style: GoogleFonts.inter(color: const Color(0xFF8A8FA8))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D37F).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('ACTIVE STREAM', style: TextStyle(color: Color(0xFF00D37F), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const LiveEarningsTicker(ratePerSecond: 0.000192, initialEarned: 14.852100),
                  const SizedBox(height: 8),
                  Text('Rate: 500 USDC / 30 Days', style: GoogleFonts.inter(color: const Color(0xFF8A8FA8), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
