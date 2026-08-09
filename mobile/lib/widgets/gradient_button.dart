import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A full-width gradient button with optional loading spinner.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final Color color;

  const GradientButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.color = const Color(0xFF00D37F),
    super.key,
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
