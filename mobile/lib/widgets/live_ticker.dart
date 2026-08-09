import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiveEarningsTicker extends StatefulWidget {
  final double ratePerSecond;
  final double initialEarned;

  const LiveEarningsTicker({
    required this.ratePerSecond,
    required this.initialEarned,
    super.key,
  });

  @override
  State<LiveEarningsTicker> createState() => _LiveEarningsTickerState();
}

class _LiveEarningsTickerState extends State<LiveEarningsTicker> {
  late double _displayed;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _displayed = widget.initialEarned;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {
          _displayed += widget.ratePerSecond / 10.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '\$${_displayed.toStringAsFixed(6)}',
      style: GoogleFonts.spaceGrotesk(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF00D37F),
      ),
    );
  }
}
