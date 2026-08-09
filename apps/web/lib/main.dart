import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:js_interop';

// ==============================================================
// 1. JS INTEROP (inFlow Stellar Bridge)
// ==============================================================
@JS('window.StellarBridge')
external StellarBridge get stellarBridge;

@JS()
extension type StellarBridge._(JSObject _) implements JSObject {
  external JSPromise initBridge();
  external JSPromise sendEmailOtp(JSString email);
  external JSPromise verifyEmailOtpAndConnect(JSString otp, JSString network);
  external JSPromise createStream(JSString token, JSString amount, JSNumber duration);
}

// ==============================================================
// 2. THEME & CONSTANTS
// ==============================================================
class AppTheme {
  static const Color primary = Color(0xFF14F195);
  static const Color secondary = Color(0xFF9945FF);
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color cardBg = Color(0xFF13131A);
  static const Color border = Color(0xFF2A2A35);
  static const Color text = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF8B8B99);
}

// ==============================================================
// 3. UI UTILITIES
// ==============================================================
class GlassCard extends StatelessWidget {
  final Widget child;
  final double padding;
  const GlassCard({super.key, required this.child, this.padding = 24});
  @override Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: AppTheme.cardBg.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ==============================================================
// 4. MAIN FUNCTION
// ==============================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InFlowStellarApp());
}

class InFlowStellarApp extends StatelessWidget {
  const InFlowStellarApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(
      title: 'inFlow Stellar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppTheme.bgDark,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(primary: AppTheme.primary, surface: AppTheme.cardBg),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/story': (context) => const StoryScreen(),
      },
    );
  }
}

// ==============================================================
// 5. LANDING SCREEN (4 states)
// ==============================================================
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _otpSent = false;
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  void _sendOtp() {
    setState(() => _otpSent = true);
  }

  void _verifyOtp() {
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(top: -100, left: -100, child: Container(width: 400, height: 400, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x339945FF), boxShadow: [BoxShadow(blurRadius: 100, color: Color(0x339945FF))]))),
          Positioned(bottom: -100, right: -100, child: Container(width: 400, height: 400, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x3314F195), boxShadow: [BoxShadow(blurRadius: 100, color: Color(0x3314F195))]))),
          Center(
            child: SizedBox(
              width: 420,
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.rocket_launch, size: 48, color: AppTheme.primary).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 24),
                    Text("inFlow on Stellar", style: GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    const Text("Lightning fast salary streams. Zero fees.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                    const SizedBox(height: 32),
                    if (!_otpSent) ...[
                      TextField(controller: _emailCtrl, decoration: InputDecoration(hintText: "Enter your email", filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _sendOtp, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black), child: const Text("Continue", style: TextStyle(fontWeight: FontWeight.bold)))),
                    ] else ...[
                      TextField(controller: _otpCtrl, decoration: InputDecoration(hintText: "Enter 6-digit code", filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _verifyOtp, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black), child: const Text("Verify & Login", style: TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, curve: Curves.easeOut),
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================
// 6. DASHBOARD SCREEN
// ==============================================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Dashboard", style: GoogleFonts.syne(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: () => Navigator.pushNamed(context, '/story'), child: const Text("How it works", style: TextStyle(color: AppTheme.primary))),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 250,
            color: AppTheme.cardBg,
            child: Column(
              children: [
                _navItem("Wallet", 0, Icons.account_balance_wallet),
                _navItem("Pay", 1, Icons.send),
                _navItem("Streams", 2, Icons.water_drop),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: IndexedStack(
                index: _tab,
                children: [
                  _WalletTab(),
                  _PayTab(),
                  _StreamsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(String title, int index, IconData icon) {
    final active = _tab == index;
    return ListTile(
      leading: Icon(icon, color: active ? AppTheme.primary : AppTheme.textMuted),
      title: Text(title, style: TextStyle(color: active ? Colors.white : AppTheme.textMuted, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      onTap: () => setState(() => _tab = index),
      selected: active,
      selectedTileColor: AppTheme.primary.withOpacity(0.1),
    );
  }
}

class _WalletTab extends StatelessWidget {
  @override Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Your Wallet", style: GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Balance", style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 8),
              Text("\$12,450.00", style: GoogleFonts.syne(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ],
          ),
        ).animate().fadeIn().slideX(),
      ],
    );
  }
}

class _PayTab extends StatelessWidget {
  @override Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Send a Stream", style: GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        SizedBox(
          width: 500,
          child: GlassCard(
            child: Column(
              children: [
                TextField(decoration: InputDecoration(labelText: "Recipient Email")),
                const SizedBox(height: 16),
                TextField(decoration: InputDecoration(labelText: "Amount (USDC)")),
                const SizedBox(height: 16),
                TextField(decoration: InputDecoration(labelText: "Duration (Days)")),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: (){}, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black), child: const Text("Start Stream", style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
          ).animate().fadeIn().slideX(),
        ),
      ],
    );
  }
}

class _StreamsTab extends StatelessWidget {
  @override Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Active Streams", style: GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: 3,
            itemBuilder: (c, i) => Card(
              color: AppTheme.cardBg,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: const Icon(Icons.water_drop, color: AppTheme.primary),
                title: Text("Stream #${1000 + i}"),
                subtitle: const Text("1,000 USDC over 30 days"),
                trailing: TextButton(onPressed: (){}, child: const Text("Claim")),
              ),
            ).animate().fadeIn(delay: (i * 100).ms),
          ),
        ),
      ],
    );
  }
}

// ==============================================================
// 7. STORY SCREEN
// ==============================================================
class StoryScreen extends StatelessWidget {
  const StoryScreen({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text("How it Works")),
      body: Center(
        child: SizedBox(
          width: 600,
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 64, color: AppTheme.secondary),
                const SizedBox(height: 24),
                Text("Money that flows", style: GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text("inFlow uses Stellar to stream salaries by the second. No more waiting 2 weeks for payday. Watch your balance tick up in real time and withdraw whenever you want. Powered by Soroban smart contracts on the Stellar network.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: AppTheme.textMuted)),
                const SizedBox(height: 32),
                ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black), child: const Text("Back to App")),
              ],
            ),
          ).animate().scale(),
        ),
      ),
    );
  }
}
