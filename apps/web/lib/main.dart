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
import 'package:shimmer/shimmer.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

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
// 2. CONFIGURATION & DESIGN SYSTEM TOKENS
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

  // Expanded UI/UX Facelift Design Tokens
  static const Color cardHover = Color(0xFF12121E);
  static const Color glassWhite = Color(0x08FFFFFF);
  static const Color amberGlow = Color(0x1AF59E0B);
  static const Color greenGlow = Color(0x1400D37F);
  static const Color purpleGlow = Color(0x1A7C3AED);
  static const Color shimmer1 = Color(0xFF1A1A28);
  static const Color shimmer2 = Color(0xFF222235);
}

class InFlowConfig {
  static const String USDC_TESTNET = "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5";
  static const String USDC_MAINNET = "CCW67TSZV3SSS2HXMBQ5JFGCKJNXKZM7UQUWUZPUTHXSTZLEO7SJMI3";
  static const String WORKER_URL = "https://inflow-relay.zapstream.workers.dev";
  static const String APP_URL = "https://inflowfinance.web.app";

  static String usdcAddress(bool isMainnet) => isMainnet ? USDC_MAINNET : USDC_TESTNET;

  static String getExplorerUrl(String addressOrTx, bool isMainnet, {bool isAddress = false}) {
    String net = isMainnet ? "public" : "testnet";
    String path = isAddress ? "account" : "tx";
    return "https://stellar.expert/explorer/$net/$path/$addressOrTx";
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
// 3. REUSABLE FACELIFT COMPONENTS
// ==============================================================

/// Glassmorphism Card Container with ambient glow shadows
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;
  final Color? borderColor;
  final Color? backgroundColor;
  final List<BoxShadow>? extraShadows;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius,
    this.borderColor,
    this.backgroundColor,
    this.extraShadows,
  });

  @override
  Widget build(BuildContext context) {
    final borderRad = radius ?? BorderRadius.circular(20);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.cardBg,
        borderRadius: borderRad,
        border: Border.all(color: borderColor ?? AppTheme.border, width: 1),
        boxShadow: extraShadows ??
            [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 32, offset: const Offset(0, 8)),
              BoxShadow(color: AppTheme.amber.withValues(alpha: 0.03), blurRadius: 40, spreadRadius: 2),
            ],
      ),
      child: child,
    );
  }
}

/// Truncated string + copy-to-clipboard button with pop-check animation
class CopyableText extends StatefulWidget {
  final String text;
  final String? displayText;
  final TextStyle? style;
  final Color iconColor;

  const CopyableText({
    super.key,
    required this.text,
    this.displayText,
    this.style,
    this.iconColor = AppTheme.dim,
  });

  @override
  State<CopyableText> createState() => _CopyableTextState();
}

class _CopyableTextState extends State<CopyableText> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.text));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    BannerUtils.showBanner("Copied to clipboard!", context: context, isError: false, durationSecs: 2);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String _formatDisplay() {
    if (widget.displayText != null) return widget.displayText!;
    if (widget.text.length > 16) {
      return "${widget.text.substring(0, 6)}...${widget.text.substring(widget.text.length - 6)}";
    }
    return widget.text;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_formatDisplay(), style: widget.style ?? GoogleFonts.jetBrainsMono(fontSize: 13, color: AppTheme.text)),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: _copied
                  ? const Icon(Icons.check_circle, key: ValueKey('check'), color: AppTheme.green, size: 16)
                  : Icon(Icons.copy_rounded, key: const ValueKey('copy'), color: widget.iconColor, size: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing status dot (infinite ring animation)
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({super.key, this.color = AppTheme.green, this.size = 8});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.size + (8 * _controller.value),
              height: widget.size + (8 * _controller.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: (1.0 - _controller.value) * 0.5),
              ),
            ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        );
      },
    );
  }
}

/// Contextual Tooltip Icon widget
class InfoTooltip extends StatelessWidget {
  final String message;
  final Color color;
  final double size;

  const InfoTooltip({super.key, required this.message, this.color = AppTheme.dim, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141420),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
      ),
      textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Icon(Icons.help_outline_rounded, color: color, size: size),
      ),
    );
  }
}

/// Shimmer Skeleton Box
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? radius;

  const ShimmerBox({super.key, required this.width, required this.height, this.radius});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.shimmer1,
      highlightColor: AppTheme.shimmer2,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.shimmer1,
          borderRadius: radius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Amber Primary Button with press scaling
class AmberButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double? width;

  const AmberButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
  });

  @override
  State<AmberButton> createState() => _AmberButtonState();
}

class _AmberButtonState extends State<AmberButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: widget.width ?? double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: widget.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[Icon(widget.icon, size: 18), const SizedBox(width: 8)],
                      Text(widget.label, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Green Action Button
class GreenButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const GreenButton({super.key, required this.label, this.onPressed, this.icon, this.isLoading = false});

  @override
  State<GreenButton> createState() => _GreenButtonState();
}

class _GreenButtonState extends State<GreenButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: widget.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[Icon(widget.icon, size: 18), const SizedBox(width: 8)],
                      Text(widget.label, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Ghost Outlined Button
class GhostButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = AppTheme.amber,
    this.icon,
  });

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: widget.onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.color,
              side: BorderSide(color: widget.color.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[Icon(widget.icon, size: 16), const SizedBox(width: 6)],
                Text(widget.label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Banner Utils
class BannerUtils {
  static void showBanner(String message, {BuildContext? context, bool isError = true, int durationSecs = 3}) {
    if (context == null || !context.mounted) return;
    try {
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => FloatingBanner(
          message: message,
          isError: isError,
          duration: Duration(seconds: durationSecs),
          onDismissed: () => overlayEntry.remove(),
        ),
      );
      overlay.insert(overlayEntry);
    } catch (e) {
      debugPrint("⚠️ [BannerUtils] Failed to display banner: $e");
    }
  }
}

class FloatingBanner extends StatefulWidget {
  final String message;
  final bool isError;
  final Duration duration;
  final VoidCallback? onDismissed;

  const FloatingBanner({
    super.key,
    required this.message,
    this.isError = true,
    this.duration = const Duration(seconds: 3),
    this.onDismissed,
  });

  @override
  State<FloatingBanner> createState() => _FloatingBannerState();
}

class _FloatingBannerState extends State<FloatingBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350), reverseDuration: const Duration(milliseconds: 250));
    _offsetAnimation = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (widget.onDismissed != null) widget.onDismissed!();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isError ? AppTheme.red : AppTheme.green;
    final icon = widget.isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 12))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.black, size: 20),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: GoogleFonts.plusJakartaSans(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class KeyboardScrollWrapper extends StatefulWidget {
  final Widget child;
  final ScrollController controller;

  const KeyboardScrollWrapper({super.key, required this.child, required this.controller});

  @override
  State<KeyboardScrollWrapper> createState() => _KeyboardScrollWrapperState();
}

class _KeyboardScrollWrapperState extends State<KeyboardScrollWrapper> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (FocusManager.instance.primaryFocus?.context?.widget is! EditableText) _focusNode.requestFocus();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (FocusManager.instance.primaryFocus?.context?.widget is! EditableText) _focusNode.requestFocus();
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          canRequestFocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) return KeyEventResult.ignored;
              const double scrollAmount = 150.0;
              const double pageScrollAmount = 400.0;
              double target = widget.controller.offset;
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                target += scrollAmount;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                target -= scrollAmount;
              } else if (event.logicalKey == LogicalKeyboardKey.pageDown || event.logicalKey == LogicalKeyboardKey.space) {
                target += pageScrollAmount;
              } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
                target -= pageScrollAmount;
              }
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
  final double ratePerSec;
  final String label;
  final Color color;

  const LiveEarningsTicker({
    super.key,
    this.ratePerSec = 0.000032407,
    this.label = "earned since you opened this page",
    this.color = AppTheme.green,
  });

  @override
  State<LiveEarningsTicker> createState() => _LiveEarningsTickerState();
}

class _LiveEarningsTickerState extends State<LiveEarningsTicker> {
  double val = 0.0;
  late Timer timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => val += widget.ratePerSec);
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.08),
        border: Border.all(color: widget.color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text("You've earned ", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.text.withValues(alpha: 0.6))),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(anim), child: child),
            child: Text(
              "\$${val.toStringAsFixed(6)}",
              key: ValueKey(val.toStringAsFixed(6)),
              style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: widget.color, letterSpacing: -0.5),
            ),
          ),
          if (widget.label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(" ${widget.label}", style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.dim)),
          ],
        ],
      ),
    );
  }
}

String fmt(double value) => value.toStringAsFixed(2);

// Custom Dot Grid Background Painter
class DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.amber.withValues(alpha: 0.04)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;

    const double step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MaterialApp(
        title: 'inFlow Stellar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppTheme.bgDark,
          textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.amber,
            secondary: AppTheme.purple,
            surface: AppTheme.cardBg,
          ),
          useMaterial3: true,
        ),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          if (settings.name == '/how-it-works') {
            return PageRouteBuilder(
              pageBuilder: (_, __, ___) => const StoryScreen(),
              transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
              settings: settings,
            );
          }
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

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _isBridgeReady = false, _isProcessing = false, _isAuthenticating = false;
  bool _hasOtpError = false, _otpSent = false, _isMainnet = false, _isLinkClaimed = false;
  String? _targetStreamId, _intendedEmailForStream;
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _resendCountdown = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _checkDeepLink();
    Future.delayed(const Duration(milliseconds: 500), _initEngine);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 30);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        t.cancel();
      }
    });
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
            } else if (data['recipientEmail'] != null) {
              setState(() => _intendedEmailForStream = data['recipientEmail'].toString().toLowerCase());
            }
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
    if (inputEmail.isEmpty || !inputEmail.contains('@')) {
      BannerUtils.showBanner("Please enter a valid email address.", context: context, isError: true);
      return;
    }

    if (_targetStreamId != null && _intendedEmailForStream != null) {
      if (inputEmail != _intendedEmailForStream) {
        BannerUtils.showBanner("This email is not authorized to claim this stream.", context: context, isError: true);
        return;
      }
    }
    setState(() => _isProcessing = true);
    try {
      debugPrint("[inFlow] Calling stellarBridge.sendEmailOtp for: $inputEmail");
      await stellarBridge.sendEmailOtp(inputEmail.toJS).toDart;
      debugPrint("[inFlow] OTP sent successfully!");
      setState(() => _otpSent = true);
      _startResendTimer();
    } catch (e) {
      debugPrint("[inFlow] Failed to send OTP code: $e");
      BannerUtils.showBanner("Failed to send code: $e", context: context, isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _verifyOtpAndConnect(String pin) async {
    HapticFeedback.lightImpact();
    setState(() {
      _hasOtpError = false;
      _isAuthenticating = true;
    });
    try {
      final networkStr = _isMainnet ? "mainnet" : "testnet";
      final addressJs = await stellarBridge.verifyOtpAndConnect(pin.trim().toJS, networkStr.toJS).toDart;
      final connectedAddress = (addressJs as JSString).toDart;
      final userEmail = _emailCtrl.text.trim().toLowerCase();

      await Future.delayed(const Duration(milliseconds: 1200));

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
          pageBuilder: (c, a, sa) => DashboardScreen(
            connectedAddress: connectedAddress,
            loggedInEmail: userEmail,
            isMainnet: _isMainnet,
            initialTabIndex: _targetStreamId != null && !_isLinkClaimed ? 2 : 0,
          ),
          transitionsBuilder: (c, a, sa, child) => FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() {
        _hasOtpError = true;
        _isAuthenticating = false;
        _otpCtrl.clear();
      });
      BannerUtils.showBanner("Invalid secure code. Please try again.", context: context, isError: true);
    }
  }

  Widget _buildNetworkToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleItem("Stellar Testnet", !_isMainnet, AppTheme.amber, () {
            HapticFeedback.lightImpact();
            setState(() => _isMainnet = false);
          }),
          _toggleItem("Stellar Mainnet", _isMainnet, AppTheme.green, () {
            HapticFeedback.lightImpact();
            setState(() => _isMainnet = true);
          }),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, bool active, Color activeColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (active) const PulseDot(color: Colors.black, size: 6),
            if (active) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: active ? Colors.black : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return _buildAuthenticatingScreen();
    }
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: DotGridPainter())),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x22F59E0B), Colors.transparent],
                  center: Alignment(0, -0.6),
                  radius: 1.2,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,
            right: MediaQuery.of(context).size.width * 0.05,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x1A7C3AED), Colors.transparent], radius: 0.7),
              ),
            ),
          ),
          KeyboardScrollWrapper(
            controller: _scrollController,
            child: Center(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Container(
                  width: 440,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                  child: !_isBridgeReady
                      ? _buildLoadingEngine()
                      : (_isLinkClaimed
                          ? _buildClaimedUI()
                          : (_targetStreamId != null ? _buildBeingPaidUI() : _buildSignInUI())),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatingScreen() {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: AppTheme.amber.withValues(alpha: 0.2), blurRadius: 30)],
            ),
            child: const Center(child: Icon(Icons.flash_on_rounded, color: AppTheme.amber, size: 40)),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -6, end: 6, duration: 2500.ms),
          const SizedBox(height: 36),
          Text("Signing you in securely...", style: GoogleFonts.syne(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Setting up your non-custodial Stellar wallet", style: GoogleFonts.plusJakartaSans(color: AppTheme.dim, fontSize: 14)),
          const SizedBox(height: 36),
          Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _authStepRow("✓  Verifying secure code", true),
                const SizedBox(height: 12),
                _authStepRow("⟳  Deriving HKDF keypair", true, isActive: true),
                const SizedBox(height: 12),
                _authStepRow("○  Funding account via Friendbot", false),
                const SizedBox(height: 12),
                _authStepRow("○  Ready", false),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text("No seed phrase required · Zero gas fees", style: GoogleFonts.jetBrainsMono(color: AppTheme.textMuted, fontSize: 11)),
        ],
      )),
    );
  }

  Widget _authStepRow(String label, bool isDone, {bool isActive = false}) {
    return Row(
      children: [
        if (isActive)
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppTheme.amber, strokeWidth: 2))
        else
          Text(isDone ? "✓" : "○", style: TextStyle(color: isDone ? AppTheme.green : AppTheme.textMuted, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        Text(
          label.replaceAll(RegExp(r'^[✓⟳○]\s*'), ''),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: isDone ? Colors.white : AppTheme.textMuted,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingEngine() {
    return GlassCard(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.flash_on_rounded, color: AppTheme.amber, size: 48)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.9, end: 1.1, duration: 1000.ms),
          const SizedBox(height: 24),
          Text("Connecting to Stellar Network...", style: GoogleFonts.syne(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const ShimmerBox(width: 200, height: 8),
          const SizedBox(height: 24),
          const ShimmerBox(width: double.infinity, height: 48),
        ],
      ),
    );
  }

  Widget _buildClaimedUI() {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.lock_shield_fill, size: 64, color: AppTheme.amber),
          const SizedBox(height: 24),
          Text("Link Already Claimed", style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          const Text("This payment link has already been claimed by the recipient.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 14, height: 1.5)),
          const SizedBox(height: 32),
          AmberButton(
            label: "Go to Sign In",
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _targetStreamId = null;
                _isLinkClaimed = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignInUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildNetworkToggle().animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 32),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: AppTheme.amber.withValues(alpha: 0.15), blurRadius: 20)],
          ),
          child: const Center(child: Icon(Icons.flash_on_rounded, color: AppTheme.amber, size: 36)),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        Text("Your work ends.\nYour pay starts.", textAlign: TextAlign.center, style: GoogleFonts.syne(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -1.2, height: 1.15, color: Colors.white)).animate().fadeIn(delay: 80.ms),
        const SizedBox(height: 12),
        const Text("Real-time salary streaming for Africa's workforce. No bank. No delay. Just email.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 14, height: 1.7)).animate().fadeIn(delay: 160.ms),
        const SizedBox(height: 20),
        const LiveEarningsTicker().animate().fadeIn(delay: 240.ms),
        const SizedBox(height: 32),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("EMAIL AUTHENTICATION", style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.dim, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              const SizedBox(height: 14),
              if (!_otpSent) ...[
                TextField(
                  controller: _emailCtrl,
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.dim, size: 20),
                    hintText: "your@email.com",
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.amber)),
                  ),
                ),
                const SizedBox(height: 16),
                AmberButton(
                  label: "Continue with Email →",
                  isLoading: _isProcessing,
                  onPressed: _sendOtp,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _trustBadge("⭐ Stellar"),
                    const SizedBox(width: 8),
                    _trustBadge("⛽ Zero Gas"),
                    const SizedBox(width: 8),
                    _trustBadge("📧 Email Only"),
                  ],
                ),
              ] else ...[
                Text("We sent a 6-digit code to", style: GoogleFonts.plusJakartaSans(color: AppTheme.dim, fontSize: 13)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(child: Text(_emailCtrl.text, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppTheme.amber, size: 16),
                      onPressed: () => setState(() {
                        _otpSent = false;
                        _otpCtrl.clear();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildPinput(),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _resendCountdown == 0 ? _sendOtp : null,
                    child: Text(
                      _resendCountdown > 0 ? "Resend code in ${_resendCountdown}s" : "Resend code",
                      style: GoogleFonts.plusJakartaSans(color: _resendCountdown == 0 ? AppTheme.amber : AppTheme.dim, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(delay: 320.ms),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/how-it-works'),
          child: const Text("How inFlow works →", style: TextStyle(color: AppTheme.amber, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
        ).animate().fadeIn(delay: 420.ms),
      ],
    );
  }

  Widget _trustBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.dim)),
    );
  }

  Widget _buildBeingPaidUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassCard(
          backgroundColor: const Color(0x1400D37F),
          borderColor: AppTheme.green.withValues(alpha: 0.3),
          child: Column(
            children: [
              const Text("🎉", style: TextStyle(fontSize: 44)),
              const SizedBox(height: 14),
              Text("You're being paid.\nRight now.", textAlign: TextAlign.center, style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2, letterSpacing: -0.8)),
              const SizedBox(height: 10),
              const Text("Someone set up a real-time salary stream for you. Every second that passes, money accumulates — and it's yours the moment you sign in.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 14, height: 1.65)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), border: Border.all(color: AppTheme.green.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const PulseDot(color: AppTheme.green, size: 6),
                        const SizedBox(width: 6),
                        Text("EARNINGS TICKING UP", style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const LiveEarningsTicker(ratePerSec: 0.000115741, label: "", color: AppTheme.green),
                    const SizedBox(height: 4),
                    Text("Stream #$_targetStreamId", style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_otpSent) ...[
                Text("ACCESS YOUR EARNINGS", style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.dim, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailCtrl,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.dim),
                    hintText: "Enter your email",
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.green)),
                  ),
                ),
                const SizedBox(height: 14),
                GreenButton(
                  label: "Sign In & Start Collecting →",
                  isLoading: _isProcessing,
                  onPressed: _sendOtp,
                ),
              ] else ...[
                Text("Enter the 6-digit code sent to ${_emailCtrl.text}", style: const TextStyle(color: AppTheme.dim, fontSize: 13)),
                const SizedBox(height: 16),
                _buildPinput(isGreen: true),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinput({bool isGreen = false}) {
    Color themeColor = isGreen ? AppTheme.green : AppTheme.amber;
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: GoogleFonts.jetBrainsMono(fontSize: 22, color: AppTheme.text, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(12), color: AppTheme.bgDark),
    );
    return Pinput(
      length: 6,
      controller: _otpCtrl,
      autofocus: true,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: defaultPinTheme.copyDecorationWith(border: Border.all(color: themeColor), boxShadow: [BoxShadow(color: themeColor.withValues(alpha: 0.14), spreadRadius: 3)]),
      submittedPinTheme: defaultPinTheme.copyDecorationWith(border: Border.all(color: _hasOtpError ? AppTheme.red : themeColor)),
      errorPinTheme: defaultPinTheme.copyDecorationWith(border: Border.all(color: AppTheme.red), boxShadow: [BoxShadow(color: AppTheme.red.withValues(alpha: 0.12), spreadRadius: 3)]),
      pinputAutovalidateMode: PinputAutovalidateMode.disabled,
      showCursor: true,
      onCompleted: (pin) => _verifyOtpAndConnect(pin),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
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
    super.key,
    required this.connectedAddress,
    required this.loggedInEmail,
    required this.isMainnet,
    this.initialTabIndex = 0,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
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
  String _streamFilter = "ALL";

  TxPhase _txPhase = TxPhase.none;
  String _txStatusMessage = "";

  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _spinController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _fetchBalances();
    _checkForSponsorship();
    _fetchMyStreams();

    _liveHeartbeat = Timer.periodic(const Duration(seconds: 8), (_) {
      _fetchBalances();
      if (_selectedIndex == 2 && _txPhase == TxPhase.none) _fetchMyStreams();
    });
  }

  @override
  void dispose() {
    _liveHeartbeat?.cancel();
    _spinController.dispose();
    _amountCtrl.dispose();
    _durationDaysCtrl.dispose();
    _recipientEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBalances() async {
    _spinController.forward(from: 0.0);
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
            if (data['sender'] == widget.connectedAddress ||
                data['recipient'] == widget.connectedAddress ||
                (data['recipientEmail'] != null && data['recipientEmail'] == widget.loggedInEmail)) {
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
    setState(() {
      _txPhase = TxPhase.processing;
      _txStatusMessage = "Collecting $amount USDC from Stream #$streamId...";
    });
    try {
      await stellarBridge.withdrawFromStream(streamId.toJS, amount.toString().toJS).toDart;
      setState(() {
        _txPhase = TxPhase.success;
        _txStatusMessage = "Successfully collected earnings!";
      });
      _fetchBalances();
      _fetchMyStreams();
    } catch (e) {
      setState(() {
        _txPhase = TxPhase.error;
        _txStatusMessage = "Withdrawal failed: $e";
      });
    }
  }

  void _cancelStream(int streamId) async {
    setState(() {
      _txPhase = TxPhase.processing;
      _txStatusMessage = "Cancelling Stream #$streamId...";
    });
    try {
      await stellarBridge.cancelStream(streamId.toJS).toDart;
      setState(() {
        _txPhase = TxPhase.success;
        _txStatusMessage = "Stream cancelled successfully.";
      });
      _fetchBalances();
      _fetchMyStreams();
    } catch (e) {
      setState(() {
        _txPhase = TxPhase.error;
        _txStatusMessage = "Cancel failed: $e";
      });
    }
  }

  void _showDepositQR() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppTheme.border)),
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Receive Funds", style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: QrImageView(data: widget.connectedAddress, size: 200),
                ),
                const SizedBox(height: 20),
                Text("Your Stellar Address", style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.dim, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                CopyableText(text: widget.connectedAddress),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                  child: Column(
                    children: [
                      _qrFeatureRow("✅ Supports USDC & XLM"),
                      _qrFeatureRow("✅ Stellar ${widget.isMainnet ? 'Mainnet' : 'Testnet'}"),
                      _qrFeatureRow("✅ Zero receive fees"),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GhostButton(label: "Close", onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _qrFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.dim)),
    );
  }

  void _showShortcutsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.border)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Keyboard Shortcuts", style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _shortcutRow("↑ / ↓", "Scroll page"),
              _shortcutRow("Space", "Scroll down"),
              _shortcutRow("W", "Wallet tab"),
              _shortcutRow("P", "Pay tab"),
              _shortcutRow("S", "Streams tab"),
              _shortcutRow("Esc", "Close dialogs"),
              const SizedBox(height: 20),
              GhostButton(label: "Close", onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortcutRow(String keyStr, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.border)),
            child: Text(keyStr, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppTheme.amber, fontWeight: FontWeight.bold)),
          ),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.dim)),
        ],
      ),
    );
  }

  void _showStreamDetailModal(StreamData stream) {
    showDialog(
      context: context,
      builder: (context) => StreamDetailModal(
        stream: stream,
        connectedAddress: widget.connectedAddress,
        loggedInEmail: widget.loggedInEmail,
        isMainnet: widget.isMainnet,
        onWithdraw: (amount) {
          Navigator.pop(context);
          _withdrawStream(stream.id, amount);
        },
        onCancel: () {
          Navigator.pop(context);
          _cancelStream(stream.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                border: Border(bottom: BorderSide(color: AppTheme.amber.withValues(alpha: 0.2))),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: AppTheme.amber.withValues(alpha: 0.3), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: AppTheme.amber, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text("inFlow", style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.isMainnet ? AppTheme.green.withValues(alpha: 0.15) : AppTheme.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.isMainnet ? AppTheme.green.withValues(alpha: 0.3) : AppTheme.amber.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        widget.isMainnet ? 'Mainnet' : 'Testnet',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isMainnet ? AppTheme.green : AppTheme.amber),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.qr_code_rounded, color: AppTheme.dim),
                      tooltip: "Receive funds",
                      onPressed: _showDepositQR,
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: AppTheme.dim),
                      tooltip: "Sign out",
                      onPressed: () => stellarBridge.logout().toDart.then((_) => Navigator.pushReplacementNamed(context, '/')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
          _buildTabContent(),
          if (_txPhase != TxPhase.none) _buildTxOverlay(),
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton.small(
              backgroundColor: AppTheme.cardBg,
              foregroundColor: AppTheme.dim,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.border)),
              onPressed: _showShortcutsDialog,
              child: const Text("?", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.account_balance_wallet_rounded, "Wallet"),
          _navItem(1, Icons.send_rounded, "Pay"),
          _navItem(2, Icons.bolt_rounded, "Streams", badgeCount: _myStreams.length),
          _navItem(3, Icons.info_outline_rounded, "Learn"),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, {int badgeCount = 0}) {
    bool selected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        if (index == 3) {
          Navigator.pushNamed(context, '/how-it-works');
          return;
        }
        setState(() => _selectedIndex = index);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: selected ? AppTheme.amber : AppTheme.dim, size: 22),
              if (badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppTheme.amber, shape: BoxShape.circle),
                    child: Text("$badgeCount", style: GoogleFonts.jetBrainsMono(fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? AppTheme.amber : AppTheme.dim)),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: selected ? 16 : 0,
            height: 2,
            decoration: BoxDecoration(color: AppTheme.amber, borderRadius: BorderRadius.circular(2)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildWalletTab();
      case 1:
        return _buildPayTab();
      case 2:
        return _buildStreamsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWalletTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Hello, ", style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.dim)),
              Text(widget.loggedInEmail, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              const PulseDot(),
              const SizedBox(width: 6),
              Text("LIVE", style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.green)),
            ],
          ),
          const SizedBox(height: 20),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text("Total Portfolio", style: GoogleFonts.spaceGrotesk(color: AppTheme.dim, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        const InfoTooltip(message: "Combined balance held in your Stellar account"),
                      ],
                    ),
                    RotationTransition(
                      turns: _spinController,
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.dim, size: 20),
                        onPressed: _fetchBalances,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    "\$$_usdcBalance",
                    key: ValueKey(_usdcBalance),
                    style: GoogleFonts.syne(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1.5),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text("$_xlmBalance XLM", style: GoogleFonts.jetBrainsMono(color: AppTheme.dim, fontSize: 13)),
                    const SizedBox(width: 6),
                    const InfoTooltip(message: "XLM is Stellar's native token used for gas fee sponsorship."),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 16),
                Text("Your Stellar Address", style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.dim, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                CopyableText(text: widget.connectedAddress),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: GhostButton(label: "📥 Receive", onPressed: _showDepositQR)),
                    const SizedBox(width: 16),
                    Expanded(child: AmberButton(label: "💸 Pay Stream", onPressed: () => setState(() => _selectedIndex = 1))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.purple, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Stellar ${widget.isMainnet ? 'Mainnet' : 'Testnet'}", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text("Sub-5s finality · \$0.000003 fee per tx", style: GoogleFonts.plusJakartaSans(color: AppTheme.dim, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: AppTheme.amber, size: 18),
                  onPressed: () => launchUrl(Uri.parse(InFlowConfig.getExplorerUrl(widget.connectedAddress, widget.isMainnet, isAddress: true))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Create Payment Stream", style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildWizardStepIndicator(),
          const SizedBox(height: 24),
          if (_payStep == 1) _buildPayStep1(),
          if (_payStep == 2) _buildPayStep2(),
          if (_payStep == 3) _buildPayStep3(),
        ],
      ),
    );
  }

  Widget _buildWizardStepIndicator() {
    return Row(
      children: [
        _stepDot(1, "Recipient"),
        _stepLine(1),
        _stepDot(2, "Amount"),
        _stepLine(2),
        _stepDot(3, "Review"),
      ],
    );
  }

  Widget _stepDot(int step, String label) {
    bool active = _payStep == step;
    bool done = _payStep > step;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppTheme.amber : (done ? AppTheme.green : AppTheme.bgDark),
            border: Border.all(color: active ? AppTheme.amber : (done ? AppTheme.green : AppTheme.border)),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.black)
                : Text("$step", style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.black : AppTheme.dim)),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: active ? Colors.white : AppTheme.dim, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _stepLine(int afterStep) {
    bool filled = _payStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: filled ? AppTheme.green : AppTheme.border,
      ),
    );
  }

  Widget _buildPayStep1() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Who are you paying?", style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _recipientEmailCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.alternate_email, color: AppTheme.dim),
              labelText: "Recipient Email Address",
              hintText: "employee@company.com",
              filled: true,
              fillColor: AppTheme.bgDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.amber)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.amber.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.amber.withValues(alpha: 0.2))),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: AppTheme.amber, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text("They'll receive an email with a secure link to claim earnings.", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.text))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AmberButton(
            label: "Continue to Amount →",
            onPressed: () {
              if (_recipientEmailCtrl.text.trim().isEmpty || !_recipientEmailCtrl.text.contains('@')) {
                BannerUtils.showBanner("Please enter a valid recipient email.", context: context, isError: true);
                return;
              }
              setState(() => _payStep = 2);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPayStep2() {
    double amount = double.tryParse(_amountCtrl.text) ?? 0;
    double days = double.tryParse(_durationDaysCtrl.text) ?? 0;
    double ratePerSec = (amount > 0 && days > 0) ? (amount / (days * 86400)) : 0;
    double ratePerHour = ratePerSec * 3600;
    double ratePerDay = ratePerSec * 86400;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("How much & for how long?", style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: "\$ ",
              suffixText: "USDC",
              labelText: "Amount (USDC)",
              filled: true,
              fillColor: AppTheme.bgDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.amber)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _durationDaysCtrl,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              suffixText: "days",
              labelText: "Duration (Days)",
              filled: true,
              fillColor: AppTheme.bgDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.amber)),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("LIVE RATE PREVIEW", style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.amber, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _rateRow("Per Second", "\$${ratePerSec.toStringAsFixed(6)} / s"),
                _rateRow("Per Hour", "\$${ratePerHour.toStringAsFixed(4)} / hr"),
                _rateRow("Per Day", "\$${ratePerDay.toStringAsFixed(2)} / day"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: GhostButton(label: "← Back", onPressed: () => setState(() => _payStep = 1))),
              const SizedBox(width: 16),
              Expanded(
                child: AmberButton(
                  label: "Review Stream →",
                  onPressed: () {
                    if (amount <= 0 || days <= 0) {
                      BannerUtils.showBanner("Please enter a valid amount and duration.", context: context, isError: true);
                      return;
                    }
                    setState(() => _payStep = 3);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rateRow(String label, String valueStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.dim)),
          Text(valueStr, style: GoogleFonts.jetBrainsMono(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPayStep3() {
    double amount = double.tryParse(_amountCtrl.text) ?? 0;
    double days = double.tryParse(_durationDaysCtrl.text) ?? 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Review & Confirm", style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _summaryRow("Recipient", _recipientEmailCtrl.text),
          _summaryRow("Amount", "$amount USDC"),
          _summaryRow("Duration", "$days Days"),
          _summaryRow("Rate", "\$${(amount / (days * 86400)).toStringAsFixed(6)} / sec"),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3))),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text("Funds are locked in a smart contract. Unstreamed funds can be cancelled at any time.", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.text))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: GhostButton(label: "← Edit", onPressed: () => setState(() => _payStep = 2))),
              const SizedBox(width: 16),
              Expanded(
                child: AmberButton(
                  label: "⚡ Start Streaming",
                  onPressed: () async {
                    setState(() {
                      _txPhase = TxPhase.processing;
                      _txStatusMessage = "Creating salary stream on Stellar...";
                    });
                    try {
                      await stellarBridge.createStream(
                        InFlowConfig.usdcAddress(widget.isMainnet).toJS,
                        _amountCtrl.text.toJS,
                        (days * 86400).toJS,
                        _recipientEmailCtrl.text.toJS,
                        true.toJS,
                      ).toDart;
                      setState(() {
                        _txPhase = TxPhase.success;
                        _txStatusMessage = "Stream created successfully!";
                        _payStep = 1;
                        _amountCtrl.clear();
                        _recipientEmailCtrl.clear();
                        _durationDaysCtrl.clear();
                      });
                    } catch (e) {
                      setState(() {
                        _txPhase = TxPhase.error;
                        _txStatusMessage = "Error: $e";
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(color: AppTheme.dim, fontSize: 14)),
          Text(val, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStreamsTab() {
    List<StreamData> filtered = _myStreams.where((s) {
      bool isIncoming = s.recipient == widget.connectedAddress || s.recipientEmail == widget.loggedInEmail;
      if (_streamFilter == "INCOMING") return isIncoming;
      if (_streamFilter == "OUTGOING") return !isIncoming;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Your Streams", style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh_rounded, color: AppTheme.dim), onPressed: _fetchMyStreams),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _filterPill("ALL", "All"),
              const SizedBox(width: 8),
              _filterPill("INCOMING", "Incoming"),
              const SizedBox(width: 8),
              _filterPill("OUTGOING", "Outgoing"),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoadingStreams
                ? ListView.builder(
                    itemCount: 3,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: ShimmerBox(width: double.infinity, height: 110),
                    ),
                  )
                : (filtered.isEmpty
                    ? _buildEmptyStreamsState()
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _buildStreamCard(filtered[index]),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(String filterKey, String label) {
    bool active = _streamFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _streamFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.amber : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppTheme.amber : AppTheme.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? Colors.black : AppTheme.dim,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStreamsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.amber.withValues(alpha: 0.08)),
            child: const Icon(Icons.bolt_rounded, size: 48, color: AppTheme.amber),
          ),
          const SizedBox(height: 20),
          Text("No Streams Found", style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Create a payment stream or ask your employer to stream salary to you.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dim, fontSize: 13)),
          const SizedBox(height: 24),
          AmberButton(
            width: 200,
            label: "Create a Stream →",
            onPressed: () => setState(() => _selectedIndex = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamCard(StreamData stream) {
    bool isIncoming = stream.recipient == widget.connectedAddress || stream.recipientEmail == widget.loggedInEmail;
    double timePassed = (DateTime.now().millisecondsSinceEpoch / 1000) - stream.startTime;
    double duration = (stream.stopTime - stream.startTime).toDouble();
    double progress = duration > 0 ? (timePassed / duration).clamp(0.0, 1.0) : 0.0;
    double unlockedAmount = (progress * stream.deposit).clamp(0.0, stream.deposit);

    return GestureDetector(
      onTap: () => _showStreamDetailModal(stream),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isIncoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: isIncoming ? AppTheme.green : AppTheme.amber, size: 20),
                const SizedBox(width: 8),
                Text(isIncoming ? "INCOMING STREAM" : "OUTGOING STREAM", style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: isIncoming ? AppTheme.green : AppTheme.amber)),
                const Spacer(),
                const PulseDot(),
                const SizedBox(width: 6),
                Text("LIVE", style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.green)),
              ],
            ),
            const SizedBox(height: 12),
            Text(isIncoming ? (stream.senderEmail ?? stream.sender) : (stream.recipientEmail ?? stream.recipient), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("\$${fmt(unlockedAmount)} of \$${fmt(stream.deposit)} USDC", style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppTheme.dim)),
                Text("${(progress * 100).toStringAsFixed(1)}%", style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.bgDark,
              color: isIncoming ? AppTheme.green : AppTheme.amber,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTxOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: GlassCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_txPhase == TxPhase.processing) ...[
                    const Icon(Icons.flash_on_rounded, color: AppTheme.amber, size: 56)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveY(begin: -8, end: 8, duration: 1500.ms),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: AppTheme.amber),
                  ] else if (_txPhase == TxPhase.success) ...[
                    const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 64)
                        .animate()
                        .scale(duration: 400.ms, curve: Curves.elasticOut),
                  ] else ...[
                    const Icon(Icons.error_outline_rounded, color: AppTheme.red, size: 64),
                  ],
                  const SizedBox(height: 20),
                  Text(_txStatusMessage, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  if (_txPhase != TxPhase.processing)
                    AmberButton(
                      width: 160,
                      label: "Close",
                      onPressed: () => setState(() => _txPhase = TxPhase.none),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Stream Detail Modal Stateful Widget
class StreamDetailModal extends StatefulWidget {
  final StreamData stream;
  final String connectedAddress;
  final String loggedInEmail;
  final bool isMainnet;
  final Function(double) onWithdraw;
  final VoidCallback onCancel;

  const StreamDetailModal({
    super.key,
    required this.stream,
    required this.connectedAddress,
    required this.loggedInEmail,
    required this.isMainnet,
    required this.onWithdraw,
    required this.onCancel,
  });

  @override
  State<StreamDetailModal> createState() => _StreamDetailModalState();
}

class _StreamDetailModalState extends State<StreamDetailModal> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isIncoming = widget.stream.recipient == widget.connectedAddress || widget.stream.recipientEmail == widget.loggedInEmail;
    double timePassed = (DateTime.now().millisecondsSinceEpoch / 1000) - widget.stream.startTime;
    double duration = (widget.stream.stopTime - widget.stream.startTime).toDouble();
    double progress = duration > 0 ? (timePassed / duration).clamp(0.0, 1.0) : 0.0;
    double unlockedAmount = (progress * widget.stream.deposit).clamp(0.0, widget.stream.deposit);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppTheme.border)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Stream #${widget.stream.id}", style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close_rounded, color: AppTheme.dim), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3))),
                child: Column(
                  children: [
                    Text("UNLOCKED EARNINGS", style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.dim, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text("\$${fmt(unlockedAmount)} USDC", style: GoogleFonts.jetBrainsMono(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.green)),
                    Text("of \$${fmt(widget.stream.deposit)} total deposit", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.dim)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: progress, backgroundColor: AppTheme.bgDark, color: isIncoming ? AppTheme.green : AppTheme.amber, minHeight: 8, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 20),
              _modalDetailRow("Rate / second", "\$${widget.stream.ratePerSecond.toStringAsFixed(6)}"),
              _modalDetailRow("Rate / day", "\$${(widget.stream.ratePerSecond * 86400).toStringAsFixed(2)}"),
              _modalDetailRow("Withdrawn", "\$${fmt(widget.stream.withdrawnAmount)} USDC"),
              const SizedBox(height: 24),
              if (isIncoming)
                GreenButton(label: "Collect \$${fmt(unlockedAmount)} Earnings", onPressed: () => widget.onWithdraw(unlockedAmount))
              else
                GhostButton(label: "Cancel Stream", color: AppTheme.red, onPressed: widget.onCancel),
              const SizedBox(height: 12),
              GhostButton(
                label: "View on Stellar Explorer ↗",
                color: AppTheme.dim,
                onPressed: () => launchUrl(Uri.parse(InFlowConfig.getExplorerUrl(widget.connectedAddress, widget.isMainnet, isAddress: true))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.dim)),
          Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ==============================================================
// 7. STORY SCREEN
// ==============================================================
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final ScrollController _storyScrollController = ScrollController();
  int? _expandedFaq;

  @override
  void dispose() {
    _storyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> faqs = [
      {"q": "Is this safe? What if the company closes?", "a": "Funds are locked in audited smart contracts on Stellar. Once created, only the employee can withdraw their earned portion."},
      {"q": "Do I need crypto knowledge?", "a": "Zero. You sign in with email and we handle everything behind the scenes including gas sponsorship."},
      {"q": "What if the employer cancels?", "a": "Employers can only recover unearned funds. Any salary already streamed to you is permanently yours."},
      {"q": "What is Stellar fee sponsorship?", "a": "Stellar supports fee_bump transactions allowing our worker relay to pay transaction fees on your behalf."},
      {"q": "What is Soroban?", "a": "Soroban is Stellar's high-performance smart contract platform designed for fast, micro-cent financial apps."},
    ];

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        controller: _storyScrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.bgDark.withValues(alpha: 0.9),
            title: Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: AppTheme.amber),
                const SizedBox(width: 8),
                Text("inFlow", style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: AmberButton(
                  width: 130,
                  label: "Get Started →",
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Your labour is not a loan.\nIt's yours the second you do it.", style: GoogleFonts.syne(fontSize: 44, fontWeight: FontWeight.bold, height: 1.1, color: Colors.white))
                          .animate().fadeIn().slideY(begin: 0.1),
                      const SizedBox(height: 24),
                      const Text("Africa has the world's fastest-growing workforce. inFlow streams your wage down to the second on Stellar.", style: TextStyle(color: AppTheme.dim, fontSize: 18, height: 1.6))
                          .animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 48),
                      Text("THE PROBLEM IN NUMBERS", style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.amber, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                          .animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.3,
                        children: [
                          _statCard("77%", "of African workforce live paycheck to paycheck"),
                          _statCard("31+ Days", "average wait to receive monthly salary"),
                          _statCard("\$5B+", "lost annually to wage debt and cash delays"),
                          _statCard("0s", "delay with inFlow. Money moves per second"),
                        ],
                      ).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 56),
                      Text("HOW INFLOW WORKS", style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.amber, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                          .animate().fadeIn(delay: 500.ms),
                      const SizedBox(height: 24),
                      _timelineStep("01", "Sign in with Email", "No passwords, seed phrases, or wallet installs. Non-custodial keypair derived securely via HKDF from your authenticated session."),
                      _timelineStep("02", "Employer Deposits USDC", "Employer specifies recipient email, deposit amount in USDC, and streaming duration (e.g. 30 days)."),
                      _timelineStep("03", "Per-Second Salary Stream", "Soroban smart contract locks funds and unlocks salary to the microsecond. Watch your balance tick up in real time."),
                      _timelineStep("04", "Open Secure Claim Link", "Employee receives email notification with direct claim link. Money is already streaming before sign-in."),
                      _timelineStep("05", "Collect Earnings Anytime", "Employee collects accumulated earnings on demand into their wallet with zero gas fees sponsored via fee_bump."),
                      const SizedBox(height: 56),
                      Text("THE STELLAR ADVANTAGE", style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.amber, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                          .animate().fadeIn(delay: 600.ms),
                      const SizedBox(height: 16),
                      GlassCard(
                        backgroundColor: const Color(0x147C3AED),
                        borderColor: AppTheme.purple.withValues(alpha: 0.3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bolt_rounded, color: AppTheme.purple, size: 28),
                                const SizedBox(width: 12),
                                Text("Why We Built on Stellar & Soroban", style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _advantageRow("⚡ Sub-5s Finality", "Transactions confirm in under 5 seconds, making micro-earnings instantly collectible."),
                            _advantageRow("⛽ Zero Gas Fees", "Stellar fee_bump protocol allows inFlow worker relay to sponsor transaction fees on your behalf."),
                            _advantageRow("💵 Native USDC", "Direct settlement in Circle USDC on Stellar — no wrapped tokens or bridge risks."),
                            _advantageRow("🛡️ Non-Custodial Security", "Soroban smart contract enforces stream rules; unearned funds can never be stolen."),
                          ],
                        ),
                      ).animate().fadeIn(delay: 700.ms),
                      const SizedBox(height: 56),
                      Text("FREQUENTLY ASKED QUESTIONS", style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.amber, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                          .animate().fadeIn(delay: 800.ms),
                      const SizedBox(height: 16),
                      ...faqs.asMap().entries.map((e) => _faqTile(e.key, e.value["q"]!, e.value["a"]!)),
                      const SizedBox(height: 56),
                      GlassCard(
                        backgroundColor: const Color(0x1AF59E0B),
                        borderColor: AppTheme.amber.withValues(alpha: 0.4),
                        child: Column(
                          children: [
                            Text("Ready to stream your salary?", style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text("Join Africa's first real-time streaming protocol today.", style: GoogleFonts.plusJakartaSans(color: AppTheme.dim, fontSize: 14)),
                            const SizedBox(height: 24),
                            AmberButton(
                              width: 240,
                              label: "Try inFlow Now →",
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 900.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineStep(String numStr, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.amber),
            ),
            child: Center(
              child: Text(numStr, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.amber)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.dim, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _advantageRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
          const SizedBox(height: 2),
          Text(desc, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.dim)),
        ],
      ),
    );
  }

  Widget _statCard(String val, String label) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(val, style: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.amber)),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.dim, height: 1.3)),
        ],
      ),
    );
  }

  Widget _faqTile(int index, String question, String answer) {
    bool isExpanded = _expandedFaq == index;
    return GestureDetector(
      onTap: () => setState(() => _expandedFaq = isExpanded ? null : index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(question, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white))),
                Icon(isExpanded ? Icons.remove_circle_outline : Icons.add_circle_outline, color: AppTheme.amber, size: 20),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              Text(answer, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.dim, height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}
