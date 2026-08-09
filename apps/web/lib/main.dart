import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pinput/pinput.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

// ==============================================================
// 1. JS INTEROP (inFlow Stellar Bridge)
// ==============================================================
@JS('window.StellarBridge')
external StellarBridge get stellarBridge;

@JS('window.location.reload')
external void reloadWindow();

@JS()
extension type StellarBridge._(JSObject _) implements JSObject {
  external JSPromise initBridge();
  external JSPromise sendEmailOtp(JSString email);
  external JSPromise verifyOtpAndConnect(JSString otp, JSString network);
  external JSPromise logout();
  external JSPromise createStream(
    JSString tokenAddress,
    JSString amountStr,
    JSNumber durationSecs,
    JSString recipientOrEmail,
    JSBoolean isEmailGated,
  );
  external JSPromise claimSecureStream(JSNumber streamId);
  external JSPromise withdrawFromStream(JSNumber streamId, JSString amountStr);
  external JSPromise cancelStream(JSNumber streamId);
  external JSPromise getBalance(JSString tokenAddress);
  external JSPromise getNextStreamId();
  external JSPromise getStream(JSNumber streamId);
  external JSPromise waitForTransaction(JSString txHash);
  external JSPromise checkAndTriggerSponsorship(JSString address, JSString network);
}

// ==============================================================
// 2. CONFIGURATION & DATA MODELS
// ==============================================================
class AppTheme {
  static const Color amber = Color(0xFFF59E0B);
  static const Color green = Color(0xFF00D37F);
  static const Color red = Color(0xFFFF5353);
  static const Color indigo = Color(0xFF818CF8);
  static const Color bgDark = Color(0xFF05050A);
  static const Color cardBg = Color(0xFF0C0C14);
  static const Color border = Color(0xFF1C1C2A);
  static const Color textMuted = Color(0xFF4A5168);
  static const Color dim = Color(0xFF8A8FA8);
  static const Color text = Color(0xFFEEEEF5);
  static const Color muted = Color(0xFF4A5168);
}

class InFlowStellarConfig {
  static const String USDC_TESTNET = "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5";
  static const String USDC_MAINNET = "CCW67TSZV3SSS2HXMBQ5JFGCKJNXKZM7UQUWUZPUTHXSTZLEO7SJMI3";

  static String usdcAddress(bool isMainnet) => isMainnet ? USDC_MAINNET : USDC_TESTNET;

  static String getExplorerUrl(String txHash, bool isMainnet) {
    String base = isMainnet
        ? "https://stellar.expert/explorer/public/tx/"
        : "https://stellar.expert/explorer/testnet/tx/";
    return "$base$txHash";
  }
}

class StreamData {
  final int id;
  final String sender;
  final String recipient;
  final String asset;
  final BigInt deposit;
  final BigInt withdrawnAmount;
  final BigInt remainingBalance;
  final int startTime;
  final int stopTime;
  final String claimHash;

  StreamData({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.asset,
    required this.deposit,
    required this.withdrawnAmount,
    required this.remainingBalance,
    required this.startTime,
    required this.stopTime,
    required this.claimHash,
  });
}

enum TxPhase { none, processing, success, error }

// ==============================================================
// 3. MAIN APPLICATION
// ==============================================================
void main() {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InFlowStellarWebApp());
}

class InFlowStellarWebApp extends StatelessWidget {
  const InFlowStellarWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'inFlow — Stellar Salary Streaming',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppTheme.bgDark,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const InFlowMainScreen(),
    );
  }
}

class InFlowMainScreen extends StatefulWidget {
  const InFlowMainScreen({super.key});

  @override
  State<InFlowMainScreen> createState() => _InFlowMainScreenState();
}

class _InFlowMainScreenState extends State<InFlowMainScreen> {
  bool _isBridgeReady = false;
  bool _isMainnet = false;
  String? _userAddress;
  String _userBalance = "0.00";

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initBridge();
  }

  Future<void> _initBridge() async {
    try {
      await stellarBridge.initBridge().toDart;
      setState(() => _isBridgeReady = true);
    } catch (e) {
      debugPrint("Bridge init error: $e");
    }
  }

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) return;
    setState(() => _isLoading = true);
    try {
      await stellarBridge.sendEmailOtp(_emailController.text.toJS).toDart;
      setState(() {
        _otpSent = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) return;
    setState(() => _isLoading = true);
    try {
      final networkStr = _isMainnet ? "mainnet" : "testnet";
      final pubKeyObj = await stellarBridge.verifyOtpAndConnect(_otpController.text.toJS, networkStr.toJS).toDart;
      final pubKey = (pubKeyObj as JSString).toDart;

      setState(() {
        _userAddress = pubKey;
        _isLoading = false;
      });
      _fetchBalance();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchBalance() async {
    if (_userAddress == null) return;
    try {
      final tokenAddr = InFlowStellarConfig.usdcAddress(_isMainnet);
      final balObj = await stellarBridge.getBalance(tokenAddr.toJS).toDart;
      setState(() => _userBalance = (balObj as JSString).toDart);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [Color(0xFF0F1424), Color(0xFF05050A)],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _userAddress == null ? _buildAuthCard() : _buildDashboard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flash_on, color: AppTheme.amber, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'inFlow',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Stellar Wave',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.green, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildNetworkToggle(),
              if (_userAddress != null) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, size: 16, color: AppTheme.green),
                      const SizedBox(width: 8),
                      Text(
                        '${_userAddress!.substring(0, 4)}...${_userAddress!.substring(_userAddress!.length - 4)}',
                        style: GoogleFonts.spaceMono(fontSize: 13, color: AppTheme.text),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($_userBalance USDC)',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.dim),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isMainnet = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: !_isMainnet ? AppTheme.amber : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '✦ Stellar Testnet',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: !_isMainnet ? Colors.black : AppTheme.dim,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isMainnet = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isMainnet ? AppTheme.amber : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '✦ Stellar Mainnet',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _isMainnet ? Colors.black : AppTheme.dim,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAlignment.start,
          children: [
            Text(
              'Sign in to inFlow',
              style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            const SizedBox(width: 8),
            Text(
              'Your work ends. Your pay starts. Instant salary streaming on Stellar.',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.dim),
            ),
            const SizedBox(height: 24),
            if (!_otpSent) ...[
              TextField(
                controller: _emailController,
                style: GoogleFonts.inter(color: AppTheme.text),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(color: AppTheme.dim),
                  filled: true,
                  fillColor: AppTheme.bgDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send Verification Code', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              TextField(
                controller: _otpController,
                style: GoogleFonts.spaceMono(color: AppTheme.text, fontSize: 18),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Enter 6-Digit Code',
                  labelStyle: const TextStyle(color: AppTheme.dim),
                  filled: true,
                  fillColor: AppTheme.bgDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verify & Connect', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAlignment.start,
        children: [
          Text(
            'Payment Streams',
            style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stream, size: 48, color: AppTheme.amber),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Streams Found',
                      style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a stream link to start streaming USDC in real time.',
                      style: GoogleFonts.inter(color: AppTheme.dim),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
