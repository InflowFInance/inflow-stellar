import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:js_interop';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pinput/pinput.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

// ==============================================================
// 1. JS INTEROP (inFlow Stellar Bridge)
// ==============================================================
@JS('window.StellarBridge')
external StellarBridge get stellarBridge;

@JS('window.StellarBridge')
external JSObject? get rawStellarBridge;

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
  static const Color purple = Color(0xFF7C3AED);
  static const Color indigo = Color(0xFF818CF8);
  static const Color bgDark = Color(0xFF05050A);
  static const Color cardBg = Color(0xFF0C0C14);
  static const Color border = Color(0xFF1C1C2A);
  static const Color textMuted = Color(0xFF4A5168);
  static const Color dim = Color(0xFF8A8FA8);
  static const Color text = Color(0xFFEEEEF5);
  static const Color muted = Color(0xFF4A5168);
}

class InFlowConfig {
  static const String USDC_TESTNET = "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5";
  static const String USDC_MAINNET = "CCW67TSZV3SSS2HXMBQ5JFGCKJNXKZM7UQUWUZPUTHXSTZLEO7SJMI3";
  static const String WORKER_URL = "https://inflow-relay.your-domain.workers.dev";

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
  final String token;
  final double deposit;
  final double ratePerSecond;
  final int startTime;
  final int stopTime;
  final double withdrawnAmount;
  final double remainingBalance;
  final String? senderEmail;
  final String? recipientEmail;

  StreamData({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.token,
    required this.deposit,
    required this.ratePerSecond,
    required this.startTime,
    required this.stopTime,
    required this.withdrawnAmount,
    required this.remainingBalance,
    this.senderEmail,
    this.recipientEmail,
  });
}

enum TxPhase { none, processing, success, error }

// ==============================================================
// 3. UI UTILITIES
// ==============================================================
class BannerUtils {
  static void showBanner(String message, {BuildContext? context, bool isError = true, int durationSecs = 3}) {
    if (context == null || !context.mounted) return;
    try {
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => FloatingBanner(message: message, isError: isError, duration: Duration(seconds: durationSecs), onDismissed: () => overlayEntry.remove()),
      );
      overlay.insert(overlayEntry);
    } catch (e) {
      debugPrint("⚠️ [BannerUtils] Failed to display banner: $e");
    }
  }
}

class FloatingBanner extends StatefulWidget {
  final String message; final bool isError; final Duration duration; final VoidCallback? onDismissed;
  const FloatingBanner({super.key, required this.message, this.isError = true, this.duration = const Duration(seconds: 3), this.onDismissed});
  @override State<FloatingBanner> createState() => _FloatingBannerState();
}

class _FloatingBannerState extends State<FloatingBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller; late Animation<Offset> _offsetAnimation;
  @override void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350), reverseDuration: const Duration(milliseconds: 250));
    _offsetAnimation = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    Future.delayed(widget.duration, () { if (mounted) { _controller.reverse().then((_) { if (widget.onDismissed != null) widget.onDismissed!(); }); } });
  }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final color = widget.isError ? AppTheme.red : AppTheme.green;
    final icon = widget.isError ? "✕" : "✓";
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(position: _offsetAnimation, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(color: Colors.transparent, child: Container(
            margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 12))]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(icon, style: GoogleFonts.jetBrainsMono(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(width: 12),
              Flexible(child: Text(widget.message, style: GoogleFonts.plusJakartaSans(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          )),
        )),
      ),
    );
  }
}

class KeyboardScrollWrapper extends StatefulWidget {
  final Widget child; final ScrollController controller;
  const KeyboardScrollWrapper({super.key, required this.child, required this.controller});
  @override State<KeyboardScrollWrapper> createState() => _KeyboardScrollWrapperState();
}
class _KeyboardScrollWrapperState extends State<KeyboardScrollWrapper> {
  final FocusNode _focusNode = FocusNode();
  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) { _focusNode.requestFocus(); }); }
  @override void dispose() { _focusNode.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) { if (FocusManager.instance.primaryFocus?.context?.widget is! EditableText) _focusNode.requestFocus(); },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () { if (FocusManager.instance.primaryFocus?.context?.widget is! EditableText) _focusNode.requestFocus(); },
        child: Focus(
          focusNode: _focusNode, autofocus: true, canRequestFocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) return KeyEventResult.ignored;
              const double scrollAmount = 150.0; const double pageScrollAmount = 400.0;
              double target = widget.controller.offset;
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                target += scrollAmount;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) target -= scrollAmount;
              else if (event.logicalKey == LogicalKeyboardKey.pageDown || event.logicalKey == LogicalKeyboardKey.space) target += pageScrollAmount;
              else if (event.logicalKey == LogicalKeyboardKey.pageUp) target -= pageScrollAmount;
              if (target != widget.controller.offset) {
                target = target.clamp(0.0, widget.controller.position.maxScrollExtent);
                widget.controller.animateTo(target, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class LiveEarningsTicker extends StatefulWidget {
  final double ratePerSec; final String label; final Color color;
  const LiveEarningsTicker({super.key, this.ratePerSec = 0.000032407, this.label = "earned since you opened this page", this.color = AppTheme.green});
  @override State<LiveEarningsTicker> createState() => _LiveEarningsTickerState();
}
class _LiveEarningsTickerState extends State<LiveEarningsTicker> {
  double val = 0.0; late Timer timer;
  @override void initState() { super.initState(); timer = Timer.periodic(const Duration(seconds: 1), (t) { if (mounted) setState(() => val += widget.ratePerSec); }); }
  @override void dispose() { timer.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.08), border: Border.all(color: widget.color.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text("You've earned ", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.text.withValues(alpha: 0.5))),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text("\$${val.toStringAsFixed(6)}", style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.bold, color: widget.color, letterSpacing: -0.5)).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.02, duration: 200.ms),
            ),
          ),
          Flexible(
            child: Text(" ${widget.label}", style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.text.withValues(alpha: 0.4))),
          ),
        ]
      )
    );
  }
}

String fmt(double value) => value.toStringAsFixed(2);

// ==============================================================
// 4. MAIN FUNCTION & APP ROOT
// ==============================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(const InFlowStellarApp());
}

class InFlowStellarApp extends StatelessWidget {
  const InFlowStellarApp({super.key});
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MaterialApp(
        title: 'inFlow Stellar', debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark, scaffoldBackgroundColor: AppTheme.bgDark,
          textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
          colorScheme: const ColorScheme.dark(primary: AppTheme.amber, secondary: AppTheme.purple, surface: AppTheme.cardBg),
          useMaterial3: true,
        ),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          if (settings.name == '/how-it-works') return PageRouteBuilder(pageBuilder: (_, __, ___) => const StoryScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c), settings: settings);
          return MaterialPageRoute(builder: (context) => const LandingScreen(), settings: settings);
        },
      ),
    );
  }
}

// ==============================================================
// 5. LANDING SCREEN
// ==============================================================
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _isBridgeReady = false, _isProcessing = false, _isAuthenticating = false;
  bool _hasOtpError = false, _otpSent = false, _isMainnet = false, _isLinkClaimed = false;
  String? _targetStreamId, _intendedEmailForStream;
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override void initState() {
    super.initState();
    _checkDeepLink();
    Future.delayed(const Duration(milliseconds: 500), _initEngine);
  }

  @override void dispose() {
    _emailCtrl.dispose(); _otpCtrl.dispose(); _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkDeepLink() async {
    try {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('stream') || uri.queryParameters.containsKey('id')) {
        setState(() => _targetStreamId = uri.queryParameters['stream'] ?? uri.queryParameters['id']);
        try {
          final res = await http.get(Uri.parse('${InFlowConfig.WORKER_URL}/stream-info?id=$_targetStreamId'));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data.containsKey('network')) setState(() => _isMainnet = data['network'] == "mainnet");
            if (data['isClaimed'] == true) {
              setState(() => _isLinkClaimed = true);
            } else if (data['recipientEmail'] != null) setState(() => _intendedEmailForStream = data['recipientEmail'].toString().toLowerCase());
          }
        } catch (e) {
          debugPrint("❌ [DeepLink] Failed to fetch stream info: $e");
        }
      }
    } catch (e) {
      debugPrint("❌ [DeepLink] Error handling deep link: $e");
    }
  }

  Future<void> _initEngine() async {
    try {
      bool hasBridge = rawStellarBridge != null;
      if (!hasBridge) {
        if (mounted) BannerUtils.showBanner("System UI Error: Bridge missing. Clear cache and reload.", context: context, isError: true);
        return;
      }
      await stellarBridge.initBridge().toDart;
      if (mounted) setState(() => _isBridgeReady = true);
    } catch (e) {
      if (mounted) BannerUtils.showBanner("Failed to initialize Web3. Please reload.", context: context, isError: true);
    }
  }

  Future<void> _sendOtp() async {
    HapticFeedback.lightImpact();
    final inputEmail = _emailCtrl.text.trim().toLowerCase();
    if (inputEmail.isEmpty) return;

    if (_targetStreamId != null && _intendedEmailForStream != null) {
      if (inputEmail != _intendedEmailForStream) {
        BannerUtils.showBanner("This email is not authorized to claim this stream.", context: context, isError: true);
        return;
      }
    }
    setState(() => _isProcessing = true);
    try {
      await stellarBridge.sendEmailOtp(inputEmail.toJS).toDart;
      setState(() => _otpSent = true);
    } catch (e) {
      BannerUtils.showBanner("Failed to send code.", context: context, isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _verifyOtpAndConnect(String pin) async {
    HapticFeedback.lightImpact();
    setState(() { _hasOtpError = false; _isAuthenticating = true; });
    try {
      final networkStr = _isMainnet ? "mainnet" : "testnet";
      final addressJs = await stellarBridge.verifyOtpAndConnect(pin.trim().toJS, networkStr.toJS).toDart;
      final connectedAddress = (addressJs as JSString).toDart;
      final userEmail = _emailCtrl.text.trim().toLowerCase();

      await Future.delayed(const Duration(milliseconds: 800));

      if (_targetStreamId != null && !_isLinkClaimed) {
        try { 
          await stellarBridge.claimSecureStream(int.parse(_targetStreamId!).toJS).toDart; 
        } catch (e) {
          debugPrint("❌ [Auth] Error claiming stream: $e");
        }
      }

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a, sa) => DashboardScreen(connectedAddress: connectedAddress, loggedInEmail: userEmail, isMainnet: _isMainnet, initialTabIndex: _targetStreamId != null && !_isLinkClaimed ? 2 : 0),
          transitionsBuilder: (c, a, sa, child) => FadeTransition(opacity: a, child: child), transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() { _hasOtpError = true; _isAuthenticating = false; _otpCtrl.clear(); });
      BannerUtils.showBanner("Invalid secure code. Please try again.", context: context, isError: true);
    }
  }

  Widget _buildNetworkToggle() {
    return Container(
      padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: const Color(0xFF0A0A10), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _toggleItem("Stellar Testnet", !_isMainnet, () { HapticFeedback.lightImpact(); setState(() => _isMainnet = false); }),
        _toggleItem("Stellar Mainnet", _isMainnet, () { HapticFeedback.lightImpact(); setState(() => _isMainnet = true); }),
      ]),
    );
  }

  Widget _toggleItem(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: active ? AppTheme.amber : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.black : AppTheme.textMuted)),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: AppTheme.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(26), border: Border.all(color: AppTheme.amber.withValues(alpha: 0.25))), child: const Center(child: Icon(Icons.flash_on, color: AppTheme.amber, size: 32))).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -7, end: 7, duration: 3500.ms),
          const SizedBox(height: 32), Text("Signing you in securely...", style: GoogleFonts.syne(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 8), const Text("Setting up your wallet on Stellar", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 24), const CircularProgressIndicator(color: AppTheme.amber),
        ])),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: RadialGradient(colors: [Color(0x19F59E0B), Colors.transparent], center: Alignment(0, -0.6), radius: 1.2)))),
          Positioned(top: MediaQuery.of(context).size.height * 0.08, left: MediaQuery.of(context).size.width * 0.15, child: Container(width: 320, height: 320, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x0AF59E0B), Colors.transparent], radius: 0.7)))),
          Positioned(bottom: MediaQuery.of(context).size.height * 0.15, right: MediaQuery.of(context).size.width * 0.1, child: Container(width: 240, height: 240, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x1A7C3AED), Colors.transparent], radius: 0.7)))),
          
          KeyboardScrollWrapper(
            controller: _scrollController,
            child: Center(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Container(
                  width: 420, padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                  child: !_isBridgeReady ? _buildLoadingEngine() : (_isLinkClaimed ? _buildClaimedUI() : (_targetStreamId != null ? _buildBeingPaidUI() : _buildSignInUI())),
                ),
              ),
            ),
          ),
        ]
      )
    );
  }

  Widget _buildLoadingEngine() {
    return const Center(child: Column(
      children: [
        CircularProgressIndicator(color: AppTheme.amber),
        SizedBox(height: 16),
        Text("Connecting to Stellar...", style: TextStyle(color: AppTheme.textMuted))
      ]
    ));
  }

  Widget _buildClaimedUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(CupertinoIcons.lock_shield_fill, size: 64, color: AppTheme.amber), const SizedBox(height: 24),
        Text("Link Claimed", style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 12),
        const Text("This payment link has already been claimed and is no longer valid.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 14, height: 1.5)), const SizedBox(height: 32),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { HapticFeedback.lightImpact(); setState(() { _targetStreamId = null; _isLinkClaimed = false; }); }, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Go to normal sign in", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
      ],
    ).animate().fadeIn();
  }

  Widget _buildSignInUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildNetworkToggle().animate().fadeIn(duration: 450.ms), const SizedBox(height: 32),
        Container(width: 68, height: 68, decoration: BoxDecoration(color: AppTheme.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(22), border: Border.all(color: AppTheme.amber.withValues(alpha: 0.25))), child: const Center(child: Icon(Icons.flash_on, color: AppTheme.amber, size: 32))).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20), 
        Text("Your work ends.\nYour pay starts.", textAlign: TextAlign.center, style: GoogleFonts.syne(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -1.2, height: 1.15, color: Colors.white)).animate().fadeIn(delay: 80.ms), 
        const SizedBox(height: 12),
        const Text("Real-time salary streaming for Africa's workforce. No bank. No delay. Just email.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 14, height: 1.7)).animate().fadeIn(delay: 160.ms), 
        const SizedBox(height: 20),
        const LiveEarningsTicker().animate().fadeIn(delay: 240.ms),
        const SizedBox(height: 40),
        
        Container(
          padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: AppTheme.cardBg, border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              if (!_otpSent) ...[
                TextField(controller: _emailCtrl, style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.white), decoration: InputDecoration(hintText: "your@email.com", hintStyle: const TextStyle(color: AppTheme.textMuted), filled: true, fillColor: AppTheme.bgDark, contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.amber)))),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isProcessing ? null : _sendOtp, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.amber, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Text("Continue with Email →", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)))),
                const SizedBox(height: 14), const Text("Powered by Stellar · Zero Gas Fees · Email Only", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 12)),
              ] else ...[
                const Text("We sent a 6-digit code to", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 14, height: 1.5)),
                Text(_emailCtrl.text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24), _buildPinput(), const SizedBox(height: 20),
                TextButton(onPressed: () => setState(() { _otpSent = false; _otpCtrl.clear(); }), child: const Text("← Change email", style: TextStyle(color: AppTheme.dim, fontSize: 13))),
              ]
            ]
          )
        ).animate().fadeIn(delay: 320.ms),
        const SizedBox(height: 24), 
        TextButton(onPressed: () => Navigator.pushNamed(context, '/how-it-works'), child: const Text("How inFlow works →", style: TextStyle(color: AppTheme.amber, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.3))).animate().fadeIn(delay: 420.ms),
      ],
    );
  }

  Widget _buildBeingPaidUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0x1400D37F), Color(0x0A00D37F)], begin: Alignment.topLeft, end: Alignment.bottomRight), border: Border.all(color: AppTheme.green.withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(20)), child: Column(children: [const Text("🎉", style: TextStyle(fontSize: 44)), const SizedBox(height: 14), Text("You're being paid.\nRight now.", textAlign: TextAlign.center, style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2, letterSpacing: -0.8)), const SizedBox(height: 10), const Text("Someone set up a real-time salary stream for you. Every second that passes, money accumulates — and it's yours the moment you sign in.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 14, height: 1.65)), const SizedBox(height: 20), Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), border: Border.all(color: AppTheme.green.withValues(alpha: 0.15)), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text("EARNINGS TICKING UP RIGHT NOW", style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted, letterSpacing: 0.5)), const SizedBox(height: 4), LiveEarningsTicker(ratePerSec: 0.000115741, label: "", color: AppTheme.green), const SizedBox(height: 4), Text("since this page loaded · Stream #$_targetStreamId", style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))]))] )).animate().fadeIn().slideY(begin: 0.1),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppTheme.cardBg, border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              if (!_otpSent) ...[
                Text("ACCESS YOUR EARNINGS", style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppTheme.textMuted)), const SizedBox(height: 16),
                TextField(controller: _emailCtrl, style: const TextStyle(fontSize: 15, color: Colors.white), decoration: InputDecoration(hintText: "Enter your email to continue", hintStyle: const TextStyle(color: AppTheme.textMuted), filled: true, fillColor: AppTheme.bgDark, contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.green)))),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isProcessing ? null : _sendOtp, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Text("Sign In & Start Collecting →", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)))),
              ] else ...[
                const Text("Enter the code sent to", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 13)),
                Text(_emailCtrl.text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20), _buildPinput(isGreen: true),
              ],
              const SizedBox(height: 14), const Text("No wallet or crypto knowledge needed. We handle everything.", style: TextStyle(color: AppTheme.dim, fontSize: 12))
            ]
          )
        )
      ],
    );
  }

  Widget _buildPinput({bool isGreen = false}) {
    Color themeColor = isGreen ? AppTheme.green : AppTheme.amber;
    final defaultPinTheme = PinTheme(width: 48, height: 56, textStyle: GoogleFonts.jetBrainsMono(fontSize: 22, color: AppTheme.text, fontWeight: FontWeight.w600), decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(12), color: AppTheme.bgDark));
    return Column(children: [
      Pinput(length: 6, controller: _otpCtrl, autofocus: true, defaultPinTheme: defaultPinTheme, focusedPinTheme: defaultPinTheme.copyDecorationWith(border: Border.all(color: themeColor), boxShadow: [BoxShadow(color: themeColor.withValues(alpha: 0.14), spreadRadius: 3)]), submittedPinTheme: defaultPinTheme.copyDecorationWith(border: Border.all(color: _hasOtpError ? AppTheme.red : themeColor)), errorPinTheme: defaultPinTheme.copyDecorationWith(border: Border.all(color: AppTheme.red), boxShadow: [BoxShadow(color: AppTheme.red.withValues(alpha: 0.12), spreadRadius: 3)]), pinputAutovalidateMode: PinputAutovalidateMode.disabled, showCursor: true, onCompleted: (pin) => _verifyOtpAndConnect(pin), inputFormatters: [FilteringTextInputFormatter.digitsOnly]).animate().fadeIn().scale(),
    ]);
  }
}

// ==============================================================
// 6. DASHBOARD SCREEN
// ==============================================================
class DashboardScreen extends StatefulWidget {
  final String connectedAddress;
  final String loggedInEmail;
  final bool isMainnet;
  final int initialTabIndex;

  const DashboardScreen({
    super.key, required this.connectedAddress, required this.loggedInEmail,
    required this.isMainnet, this.initialTabIndex = 0,
  });
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _selectedIndex;
  String _usdcBalance = "0.00";
  String _xlmBalance = "0.00";
  Timer? _liveHeartbeat;
  bool _hasCheckedSponsorship = false;

  final _amountCtrl = TextEditingController();
  final _durationDaysCtrl = TextEditingController();
  final _recipientEmailCtrl = TextEditingController();
  int _payStep = 1;

  bool _isLoadingStreams = false;
  List<StreamData> _myStreams = [];
  final Set<int> _expandedStreams = {};
  int? _lastCreatedStreamId;
  TxPhase _txPhase = TxPhase.none;
  String _txStatusMessage = "";
  String? _txHash;

  @override void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _fetchBalances();
    _checkForSponsorship();
    _fetchMyStreams();

    _liveHeartbeat = Timer.periodic(const Duration(seconds: 8), (_) {
      _fetchBalances();
      if (_selectedIndex == 2 && _txPhase == TxPhase.none) _fetchMyStreams();
    });
  }

  @override void dispose() {
    _liveHeartbeat?.cancel();
    _amountCtrl.dispose(); _durationDaysCtrl.dispose(); _recipientEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBalances() async {
    try {
      final usdcObj = await stellarBridge.getBalance(InFlowConfig.usdcAddress(widget.isMainnet).toJS).toDart;
      final xlmObj = await stellarBridge.getBalance("native".toJS).toDart;
      if (mounted) {
        setState(() {
          _usdcBalance = (usdcObj as JSString).toDart;
          _xlmBalance = (xlmObj as JSString).toDart;
        });
      }
    } catch (e) {
      debugPrint("Error fetching balances: $e");
    }
  }

  Future<void> _checkForSponsorship() async {
    if (_hasCheckedSponsorship) return;
    try {
      final networkStr = widget.isMainnet ? "mainnet" : "testnet";
      await stellarBridge.checkAndTriggerSponsorship(widget.connectedAddress.toJS, networkStr.toJS).toDart;
      _hasCheckedSponsorship = true;
    } catch (e) {
      debugPrint("Sponsorship error: $e");
    }
  }

  Future<void> _fetchMyStreams() async {
    if (_isLoadingStreams) return;
    setState(() => _isLoadingStreams = true);
    try {
      final nextIdObj = await stellarBridge.getNextStreamId().toDart;
      final nextId = int.tryParse((nextIdObj as JSString).toDart) ?? 1;
      List<StreamData> streams = [];
      for (int i = 1; i < nextId; i++) {
        try {
          final res = await http.get(Uri.parse('${InFlowConfig.WORKER_URL}/stream-info?id=$i'));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data['sender'] == widget.connectedAddress || data['recipient'] == widget.connectedAddress || (data['recipientEmail'] != null && data['recipientEmail'] == widget.loggedInEmail)) {
              streams.add(StreamData(
                id: i,
                sender: data['sender'],
                recipient: data['recipient'] ?? '',
                token: data['asset'] ?? '',
                deposit: double.tryParse(data['deposit'] ?? '0') ?? 0,
                ratePerSecond: double.tryParse(data['ratePerSecond'] ?? '0') ?? 0,
                startTime: data['startTime'] ?? 0,
                stopTime: data['stopTime'] ?? 0,
                withdrawnAmount: double.tryParse(data['withdrawnAmount'] ?? '0') ?? 0,
                remainingBalance: double.tryParse(data['remainingBalance'] ?? '0') ?? 0,
                senderEmail: data['senderEmail'],
                recipientEmail: data['recipientEmail'],
              ));
            }
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _myStreams = streams;
          _isLoadingStreams = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStreams = false);
    }
  }

  void _withdrawStream(int streamId, double amount) async {
    setState(() { _txPhase = TxPhase.processing; _txStatusMessage = "Processing withdrawal..."; });
    try {
      await stellarBridge.withdrawFromStream(streamId.toJS, amount.toString().toJS).toDart;
      setState(() { _txPhase = TxPhase.success; _txStatusMessage = "Withdrawal successful!"; });
      _fetchBalances(); _fetchMyStreams();
    } catch (e) {
      setState(() { _txPhase = TxPhase.error; _txStatusMessage = "Withdrawal failed: $e"; });
    }
  }

  void _cancelStream(int streamId) async {
    setState(() { _txPhase = TxPhase.processing; _txStatusMessage = "Cancelling stream..."; });
    try {
      await stellarBridge.cancelStream(streamId.toJS).toDart;
      setState(() { _txPhase = TxPhase.success; _txStatusMessage = "Stream cancelled."; });
      _fetchBalances(); _fetchMyStreams();
    } catch (e) {
      setState(() { _txPhase = TxPhase.error; _txStatusMessage = "Cancel failed: $e"; });
    }
  }

  void _showDepositQR() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.border)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Deposit Crypto", style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Container(color: Colors.white, padding: const EdgeInsets.all(8), child: QrImageView(data: widget.connectedAddress, size: 200)),
                const SizedBox(height: 20),
                Text(widget.connectedAddress, textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppTheme.dim)),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStreamDetailModal(StreamData stream) {
    bool isIncoming = stream.recipient == widget.connectedAddress || stream.recipientEmail == widget.loggedInEmail;
    double timePassed = (DateTime.now().millisecondsSinceEpoch / 1000) - stream.startTime;
    double unlockedAmount = timePassed * stream.ratePerSecond;
    if (unlockedAmount > stream.deposit) unlockedAmount = stream.deposit;
    if (unlockedAmount < 0) unlockedAmount = 0;

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.border)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Stream #${stream.id}", style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text("${fmt(unlockedAmount)} USDC", style: GoogleFonts.jetBrainsMono(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.amber)),
                const Text("Unlocked Amount", style: TextStyle(color: AppTheme.dim)),
                const SizedBox(height: 32),
                if (isIncoming)
                  ElevatedButton(onPressed: () { Navigator.pop(context); _withdrawStream(stream.id, unlockedAmount); }, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, foregroundColor: Colors.black), child: const Text("Collect Available Earnings"))
                else
                  ElevatedButton(onPressed: () { Navigator.pop(context); _cancelStream(stream.id); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: AppTheme.red, side: const BorderSide(color: AppTheme.red)), child: const Text("Cancel Stream")),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppTheme.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.flash_on, color: AppTheme.amber, size: 20)),
            const SizedBox(width: 12),
            Text("inFlow", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(12)), child: Text(widget.isMainnet ? 'Mainnet' : 'Testnet', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.dim))),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code, color: AppTheme.dim), onPressed: _showDepositQR),
          IconButton(icon: const Icon(Icons.logout, color: AppTheme.dim), onPressed: () => stellarBridge.logout().toDart.then((_) => Navigator.pushReplacementNamed(context, '/'))),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.bgDark,
        selectedItemColor: AppTheme.amber,
        unselectedItemColor: AppTheme.dim,
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 3) { Navigator.pushNamed(context, '/how-it-works'); return; }
          setState(() => _selectedIndex = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "Wallet"),
          BottomNavigationBarItem(icon: Icon(Icons.send), label: "Pay"),
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: "Streams"),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: "How it Works"),
        ],
      ),
      body: Stack(
        children: [
          _buildTabContent(),
          if (_txPhase != TxPhase.none) _buildTxOverlay(),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedIndex) {
      case 0: return _buildWalletTab();
      case 1: return _buildPayTab();
      case 2: return _buildStreamsTab();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildWalletTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Balance", style: TextStyle(color: AppTheme.dim)),
                    Row(children: [Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle)), const SizedBox(width: 6), const Text("LIVE", style: TextStyle(color: AppTheme.green, fontSize: 12, fontWeight: FontWeight.bold))]),
                  ],
                ),
                const SizedBox(height: 8),
                Text("\$$_usdcBalance", style: GoogleFonts.syne(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.text)),
                const SizedBox(height: 8),
                Text("$_xlmBalance XLM", style: GoogleFonts.inter(color: AppTheme.dim)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: ElevatedButton.icon(onPressed: _showDepositQR, icon: const Icon(Icons.qr_code), label: const Text("Receive"), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.bgDark, foregroundColor: Colors.white, side: const BorderSide(color: AppTheme.border)))),
                    const SizedBox(width: 16),
                    Expanded(child: ElevatedButton.icon(onPressed: () => setState(() => _selectedIndex = 1), icon: const Icon(Icons.send), label: const Text("Send"), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.amber, foregroundColor: Colors.black))),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: Text("Powered by Stellar Soroban", style: TextStyle(color: AppTheme.dim, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildPayTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Stream Payment", style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (_payStep == 1) ...[
            TextField(controller: _recipientEmailCtrl, decoration: const InputDecoration(labelText: "Recipient Email", filled: true, fillColor: AppTheme.cardBg)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => setState(() => _payStep = 2), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text("Continue →")),
          ] else if (_payStep == 2) ...[
            TextField(controller: _amountCtrl, decoration: const InputDecoration(labelText: "Amount (USDC)", filled: true, fillColor: AppTheme.cardBg), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            TextField(controller: _durationDaysCtrl, decoration: const InputDecoration(labelText: "Duration (Days)", filled: true, fillColor: AppTheme.cardBg), keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => setState(() => _payStep = 1), child: const Text("Back"))),
                Expanded(child: ElevatedButton(onPressed: () => setState(() => _payStep = 3), child: const Text("Review →"))),
              ],
            )
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("To: ${_recipientEmailCtrl.text}", style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text("Amount: ${_amountCtrl.text} USDC", style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text("Duration: ${_durationDaysCtrl.text} Days", style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                setState(() { _txPhase = TxPhase.processing; _txStatusMessage = "Creating stream..."; });
                try {
                  double days = double.parse(_durationDaysCtrl.text);
                  await stellarBridge.createStream(
                    InFlowConfig.usdcAddress(widget.isMainnet).toJS,
                    _amountCtrl.text.toJS,
                    (days * 86400).toJS,
                    _recipientEmailCtrl.text.toJS,
                    true.toJS
                  ).toDart;
                  setState(() { _txPhase = TxPhase.success; _txStatusMessage = "Stream created successfully!"; _payStep = 1; _amountCtrl.clear(); _recipientEmailCtrl.clear(); _durationDaysCtrl.clear(); });
                } catch (e) {
                  setState(() { _txPhase = TxPhase.error; _txStatusMessage = "Error: $e"; });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.amber, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
              child: const Text("Confirm & Start Streaming ⚡", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStreamsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Your Streams", style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.bold)),
              if (_isLoadingStreams) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _myStreams.isEmpty && !_isLoadingStreams
                ? const Center(child: Text("No active streams", style: TextStyle(color: AppTheme.dim)))
                : ListView.builder(
                    itemCount: _myStreams.length,
                    itemBuilder: (context, index) => _buildStreamCard(_myStreams[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamCard(StreamData stream) {
    bool isIncoming = stream.recipient == widget.connectedAddress || stream.recipientEmail == widget.loggedInEmail;
    return GestureDetector(
      onTap: () => _showStreamDetailModal(stream),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
        child: Row(
          children: [
            Icon(isIncoming ? Icons.arrow_downward : Icons.arrow_upward, color: isIncoming ? AppTheme.green : AppTheme.amber),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isIncoming ? (stream.senderEmail ?? stream.sender) : (stream.recipientEmail ?? stream.recipient), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text("${fmt(stream.deposit)} USDC", style: TextStyle(color: AppTheme.dim)),
                ],
              ),
            ),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(8)), child: const Text("LIVE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.green))),
          ],
        ),
      ),
    );
  }

  Widget _buildTxOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.border)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_txPhase == TxPhase.processing) const CircularProgressIndicator(color: AppTheme.amber)
                  else if (_txPhase == TxPhase.success) const Icon(Icons.check_circle, color: AppTheme.green, size: 64)
                  else const Icon(Icons.error, color: AppTheme.red, size: 64),
                  const SizedBox(height: 24),
                  Text(_txStatusMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 24),
                  if (_txPhase != TxPhase.processing)
                    ElevatedButton(onPressed: () => setState(() => _txPhase = TxPhase.none), child: const Text("Close")),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================
// 7. STORY SCREEN
// ==============================================================
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});
  @override State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final ScrollController _storyScrollController = ScrollController();
  int? _expandedFaq;

  @override void dispose() { _storyScrollController.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final List<Map<String, String>> faqs = [
      {"q": "Is this safe? What if the company loses my money?", "a": "Funds are held in audited, non-custodial smart contracts on Stellar (Soroban) — the employer cannot access them once the stream is created. Only you can withdraw your earned portion."},
      {"q": "Do I need crypto knowledge?", "a": "None. We abstract everything. You sign in with email, we handle the wallet, gas sponsorship, and stream management. You just see a balance going up."},
      {"q": "What if the employer cancels?", "a": "They can only cancel the unearned portion. Any funds already 'streamed' to you are yours and cannot be reversed."},
      {"q": "What is a fee_bump transaction?", "a": "Stellar has a native feature called fee_bumps where a sponsor (our worker relay) pays the transaction fees on behalf of your email wallet account. This allows you to sign in and collect your salary for free."},
      {"q": "What is Soroban?", "a": "Soroban is Stellar's native, high-performance smart contract platform. It enables secure, gas-efficient real-time salary accrual and streaming balance calculations."}
    ];

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          const Positioned.fill(child: Opacity(opacity: 0.02, child: DecoratedBox(decoration: BoxDecoration(image: DecorationImage(image: NetworkImage("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='300' height='300'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.75' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='300' height='300' filter='url(%23n)'/%3E%3C/svg%3E"), repeat: ImageRepeat.repeat))))),
          
          CustomScrollView(
            controller: _storyScrollController,
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.bgDark.withValues(alpha: 0.92),
                elevation: 0,
                automaticallyImplyLeading: false, 
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppTheme.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.flash_on, color: AppTheme.amber, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Text("inFlow", style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.amber)),
                      ],
                    ), 
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Get Started →", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          bool isMobile = constraints.maxWidth < 600;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Hero
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(color: AppTheme.amber.withValues(alpha: 0.1), border: Border.all(color: AppTheme.amber.withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(20)),
                                      child: Text("✦ POWERED BY STELLAR SOROBAN", style: GoogleFonts.jetBrainsMono(color: AppTheme.amber, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                    ),
                                    const SizedBox(height: 24), 
                                    Text("Your labour is not a loan.\nIt's yours the second you do it.", textAlign: TextAlign.center, style: GoogleFonts.syne(fontSize: isMobile ? 38 : 54, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -2.0, color: Colors.white)),
                                    const SizedBox(height: 24), 
                                    const Text("Africa has the world's fastest-growing workforce. What it lacks is infrastructure that treats workers like first-class citizens. inFlow streams your wage down to the second.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 18, height: 1.75)),
                                  ],
                                ),
                              ),
                              _buildDivider(),

                              // Stats
                              Text("THE PROBLEM · BY THE NUMBERS", style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppTheme.textMuted)),
                              const SizedBox(height: 32), 
                              GridView.count(
                                crossAxisCount: isMobile ? 1 : 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: isMobile ? 2.5 : 1.5,
                                children: [
                                  _buildStatCard("77%", "of African workers live paycheck to paycheck", "ILO, 2023", AppTheme.amber),
                                  _buildStatCard("14–45", "days the average worker waits to get paid", "AfDB Report", AppTheme.amber),
                                  _buildStatCard("\$5B+", "lost annually to delayed salary payments", "World Bank", AppTheme.amber),
                                  _buildStatCard("0s", "delay with inFlow — money moves the second you work", "Stellar Network", AppTheme.green),
                                ],
                              ),
                              _buildDivider(),

                              // Steps
                              Text("HOW IT WORKS", style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppTheme.textMuted)),
                              const SizedBox(height: 16), 
                              Text("From payroll to your wallet.\nEvery. Single. Second.", style: GoogleFonts.syne(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.2, color: Colors.white)),
                              const SizedBox(height: 40), 
                              _buildStepCard("01", "Sign in with email", "No wallet or private keys required. Just enter your email, and a secure non-custodial Stellar wallet is created silently in the background."),
                              _buildStepCard("02", "Employer funds a stream", "The employer deposits USDC into a secure Stellar smart contract, setting the stream duration and the recipient's email address."),
                              _buildStepCard("03", "Salary drips per-second", "Your salary accumulates in real-time. Open the dashboard at any moment to watch your earnings tick up continuously."),
                              _buildStepCard("04", "Withdraw with zero gas fees", "Collect your accumulated USDC whenever you want. Our worker relay sponsors the transaction fee via Stellar's native fee_bump feature.", isLast: true),
                              _buildDivider(),

                              // Stellar Advantage Card
                              Text("THE STELLAR ADVANTAGE", style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppTheme.textMuted)),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.purple.withValues(alpha: 0.25), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.stars_rounded, color: AppTheme.purple, size: 28),
                                        const SizedBox(width: 12),
                                        Text("Why Stellar beats EVM", style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildAdvantageRow("Native USDC", "Direct issuance on Stellar. No custom bridge wrap risks or multi-pool slippage."),
                                    _buildAdvantageRow("Microsecond Costs", "Average stream interactions cost \$0.000003 — thousands of times cheaper than Ethereum or L2 networks."),
                                    _buildAdvantageRow("Invisible Gas Sponsorship", "Stellar's native fee_bump protocol completely abstracts blockchain fee mechanics for web2 users."),
                                    _buildAdvantageRow("Sub-5s Settlement", "Wage collection settles instantly, giving employees immediate access to stable cash."),
                                  ],
                                ),
                              ),
                              _buildDivider(),

                              // FAQ
                              Text("FAQ", style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppTheme.textMuted)),
                              const SizedBox(height: 16), 
                              Text("Common questions.", style: GoogleFonts.syne(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.2, color: Colors.white)),
                              const SizedBox(height: 32), 
                              ...faqs.asMap().entries.map((f) => InkWell(
                                onTap: () => setState(() => _expandedFaq = _expandedFaq == f.key ? null : f.key),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(f.value["q"]!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, height: 1.5))),
                                          AnimatedRotation(
                                            turns: _expandedFaq == f.key ? 0.125 : 0,
                                            duration: const Duration(milliseconds: 200),
                                            child: Container(
                                              width: 26, height: 26,
                                              decoration: BoxDecoration(
                                                color: _expandedFaq == f.key ? AppTheme.amber.withValues(alpha: 0.15) : const Color(0xFF111118),
                                                border: Border.all(color: _expandedFaq == f.key ? AppTheme.amber.withValues(alpha: 0.3) : AppTheme.border),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(child: Text("+", style: TextStyle(color: AppTheme.amber, fontSize: 16, fontWeight: FontWeight.bold))),
                                            ),
                                          )
                                        ],
                                      ),
                                      AnimatedCrossFade(
                                        firstChild: const SizedBox(width: double.infinity, height: 0),
                                        secondChild: Padding(
                                          padding: const EdgeInsets.only(top: 14),
                                          child: Text(f.value["a"]!, style: const TextStyle(color: AppTheme.dim, fontSize: 14, height: 1.75)),
                                        ),
                                        crossFadeState: _expandedFaq == f.key ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                        duration: const Duration(milliseconds: 200),
                                      )
                                    ],
                                  ),
                                ),
                              )),

                              // CTA
                              Padding(
                                padding: const EdgeInsets.only(top: 64, bottom: 80),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 1, height: 48,
                                      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppTheme.amber])),
                                    ),
                                    const SizedBox(height: 32),
                                    Text("Ready to get paid\nby the second?", textAlign: TextAlign.center, style: GoogleFonts.syne(fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1.2, color: Colors.white)),
                                    const SizedBox(height: 16),
                                    const Text("Sign up in under a minute. No wallet. No crypto. Just your email.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 15, height: 1.7)),
                                    const SizedBox(height: 36),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.amber,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Try inFlow Now →", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 16),
                                    Text("Live on Stellar Testnet & Mainnet · Sponsored by inFlow Relay", style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.dim)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: AppTheme.border, margin: const EdgeInsets.symmetric(vertical: 64));
  }

  Widget _buildStatCard(String value, String label, String source, Color color) { 
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardBg, border: Border.all(color: AppTheme.border, width: 1.5), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: GoogleFonts.syne(fontSize: 40, fontWeight: FontWeight.w800, color: color, letterSpacing: -1.5, height: 1)),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: AppTheme.dim, fontSize: 14, height: 1.6)),
          const Spacer(),
          Text(source, style: GoogleFonts.jetBrainsMono(color: AppTheme.dim, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildStepCard(String n, String title, String body, {bool isLast = false}) { 
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: AppTheme.amber.withValues(alpha: 0.08), border: Border.all(color: AppTheme.amber.withValues(alpha: 0.2), width: 1.5), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(n, style: GoogleFonts.jetBrainsMono(color: AppTheme.amber, fontSize: 13, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, letterSpacing: -0.3)),
                const SizedBox(height: 8),
                Text(body, style: const TextStyle(color: AppTheme.dim, fontSize: 14, height: 1.7)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAdvantageRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: AppTheme.purple, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: AppTheme.dim, fontSize: 13, height: 1.5)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
