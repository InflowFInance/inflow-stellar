import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/stream_model.dart';

/// A card summarising a single salary stream, with a withdraw action.
class StreamCard extends StatelessWidget {
  final StreamModel stream;
  final VoidCallback onWithdraw;

  const StreamCard({required this.stream, required this.onWithdraw, super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final available = stream.availableToWithdraw(now);
    final progress = stream.progressFraction(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: stream.isActive
              ? const Color(0xFF00D37F).withOpacity(0.2)
              : const Color(0xFF1C1C2A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stream #${stream.streamId}',
                style: GoogleFonts.spaceMono(
                    color: const Color(0xFF8A8FA8), fontSize: 12),
              ),
              _StatusBadge(isActive: stream.isActive),
            ],
          ),
          const SizedBox(height: 12),

          // Total amount
          Text(
            '\$${stream.deposit.toStringAsFixed(2)} USDC',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${stream.startDate.toLocal().toString().split(' ').first} → '
            '${stream.stopDate.toLocal().toString().split(' ').first}',
            style: GoogleFonts.inter(
                color: const Color(0xFF8A8FA8), fontSize: 11),
          ),

          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF1C1C2A),
              color: stream.isActive
                  ? const Color(0xFF00D37F)
                  : const Color(0xFF3C3C4A),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(1)}% elapsed',
                style: GoogleFonts.inter(
                    color: const Color(0xFF8A8FA8), fontSize: 11),
              ),
              Text(
                'Withdrawn: \$${stream.withdrawnAmount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                    color: const Color(0xFF8A8FA8), fontSize: 11),
              ),
            ],
          ),

          if (available > 0.001 && stream.isActive) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: onWithdraw,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: const Color(0xFF00D37F).withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Collect \$${available.toStringAsFixed(4)} USDC',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF00D37F),
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF00D37F).withOpacity(0.12)
            : const Color(0xFF3C3C4A).withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'ENDED',
        style: GoogleFonts.spaceMono(
          fontSize: 10,
          color:
              isActive ? const Color(0xFF00D37F) : const Color(0xFF8A8FA8),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
