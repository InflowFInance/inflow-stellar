import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../services/stellar_service.dart';
import 'dashboard_screen.dart';

class LandingScreen extends StatefulWidget {
  final StellarService stellarService;

  const LandingScreen({required this.stellarService, super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) return;
    setState(() => _isLoading = true);
    try {
      await widget.stellarService.sendOtp(_emailController.text);
      setState(() {
        _otpSent = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending code: $e')),
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) return;
    setState(() => _isLoading = true);
    try {
      await widget.stellarService.verifyOtpAndConnect(_emailController.text, _otpController.text, 'testnet');
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(stellarService: widget.stellarService),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid code: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.flash_on, color: Color(0xFFF59E0B), size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                'inFlow',
                style: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                'Real-Time Salary Streaming on Stellar',
                style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF8A8FA8)),
              ),
              const SizedBox(height: 40),
              if (!_otpSent) ...[
                TextField(
                  controller: _emailController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Work Email Address',
                    labelStyle: const TextStyle(color: Color(0xFF8A8FA8)),
                    filled: true,
                    fillColor: const Color(0xFF0C0C14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1C1C2A))),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text('Send Verification Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ] else ...[
                Pinput(
                  controller: _otpController,
                  length: 6,
                  onCompleted: (_) => _verifyOtp(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D37F),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text('Verify & Connect Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
