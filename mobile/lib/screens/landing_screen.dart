import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../providers/app_provider.dart';
import 'dashboard_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _sendOtp(AppProvider provider) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }
    await provider.sendOtp(email);
    if (mounted && provider.authError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(provider.authError!)));
    }
  }

  Future<void> _verifyOtp(AppProvider provider) async {
    if (_otpController.text.length < 6) return;
    final success =
        await provider.verifyOtp(_emailController.text.trim(), _otpController.text);
    if (mounted && success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else if (mounted && provider.authError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid code. Try again.')),
      );
      _otpController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isOtpSent = provider.authState == AuthState.otpSent ||
        provider.authState == AuthState.verifying;
    final isLoading = provider.authState == AuthState.sendingOtp ||
        provider.authState == AuthState.verifying;

    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo & badge ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x33F59E0B), Color(0x1100D37F)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x33F59E0B)),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Color(0xFFF59E0B), size: 40),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
              const SizedBox(height: 28),

              // ── Headline ──────────────────────────────────────────────────
              Text(
                'inFlow',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 8),
              Text(
                'Real-Time Salary Streaming\non Stellar',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: const Color(0xFF8A8FA8),
                  height: 1.4,
                ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 12),

              // ── Stellar badge ─────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B21B6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF5B21B6).withValues(alpha: 0.4)),
                ),
                child: Text(
                  '⭐ Powered by Soroban',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFA78BFA),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 48),

              // ── Auth card ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0C14),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1C1C2A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOtpSent ? 'Enter your code' : 'Sign in with email',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isOtpSent
                          ? 'Check your inbox — we sent a 6-digit code to ${_emailController.text.trim()}'
                          : 'No wallet or seed phrase required. Just your work email.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFF8A8FA8)),
                    ),
                    const SizedBox(height: 24),

                    if (!isOtpSent) ...[
                      // ── Email field ───────────────────────────────────────
                      TextField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Work Email Address',
                          labelStyle:
                              const TextStyle(color: Color(0xFF8A8FA8)),
                          prefixIcon: const Icon(Icons.email_outlined,
                              color: Color(0xFF8A8FA8)),
                          filled: true,
                          fillColor: const Color(0xFF05050A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFF1C1C2A)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFF1C1C2A)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFFF59E0B), width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => _sendOtp(provider),
                      ),
                      const SizedBox(height: 16),
                      _ActionButton(
                        label: 'Send Verification Code',
                        isLoading: isLoading,
                        color: const Color(0xFFF59E0B),
                        onTap: () => _sendOtp(provider),
                      ),
                    ] else ...[
                      // ── OTP PIN field ─────────────────────────────────────
                      Center(
                        child: Pinput(
                          controller: _otpController,
                          length: 6,
                          defaultPinTheme: PinTheme(
                            width: 48,
                            height: 56,
                            textStyle: GoogleFonts.spaceMono(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF05050A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF1C1C2A)),
                            ),
                          ),
                          focusedPinTheme: PinTheme(
                            width: 48,
                            height: 56,
                            textStyle: GoogleFonts.spaceMono(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF05050A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF00D37F), width: 1.5),
                            ),
                          ),
                          onCompleted: (_) => _verifyOtp(provider),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ActionButton(
                        label: 'Verify & Connect Account',
                        isLoading: isLoading,
                        color: const Color(0xFF00D37F),
                        onTap: () => _verifyOtp(provider),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => provider.sendOtp(
                              _emailController.text.trim()),
                          child: Text(
                            'Resend code',
                            style: GoogleFonts.inter(
                                color: const Color(0xFF8A8FA8), fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

              const SizedBox(height: 32),

              // ── Trust indicators ──────────────────────────────────────────
              _TrustRow().animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.isLoading,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black.withValues(alpha: 0.6)),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.lock_outline, 'No seed phrase'),
      (Icons.bolt_outlined, 'Zero gas fees'),
      (Icons.mail_outline, 'Email only'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items.map((item) {
        return Column(
          children: [
            Icon(item.$1, color: const Color(0xFF8A8FA8), size: 20),
            const SizedBox(height: 4),
            Text(
              item.$2,
              style: GoogleFonts.inter(
                  color: const Color(0xFF8A8FA8), fontSize: 11),
            ),
          ],
        );
      }).toList(),
    );
  }
}
