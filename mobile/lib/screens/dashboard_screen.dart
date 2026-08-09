import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/stream_model.dart';
import '../providers/app_provider.dart';
import '../widgets/live_ticker.dart';
import '../widgets/stream_card.dart';
import '../widgets/gradient_button.dart';
import 'landing_screen.dart';
import 'employer_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0; // 0 = Employee view, 1 = Employer view

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.user;

    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C14),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Color(0xFFF59E0B), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'inFlow',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // Network badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: provider.stellarService.network == 'mainnet'
                  ? const Color(0xFF00D37F).withValues(alpha: 0.15)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              provider.stellarService.network.toUpperCase(),
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                color: provider.stellarService.network == 'mainnet'
                    ? const Color(0xFF00D37F)
                    : const Color(0xFFF59E0B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Color(0xFF8A8FA8)),
            onPressed: () async {
              await provider.logout();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Tab bar ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _TabBar(
              selected: _tab,
              onTab: (i) => setState(() => _tab = i),
            ),
          ),
          const SizedBox(height: 4),

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: _tab == 0
                ? _EmployeeView(user: user, provider: provider)
                : _EmployerView(provider: provider),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Bar ─────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTab;

  const _TabBar({required this.selected, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1C1C2A)),
      ),
      child: Row(
        children: [
          _TabItem(
              label: 'My Earnings',
              icon: Icons.account_balance_wallet_outlined,
              selected: selected == 0,
              onTap: () => onTab(0)),
          _TabItem(
              label: 'Pay Team',
              icon: Icons.send_outlined,
              selected: selected == 1,
              onTap: () => onTab(1)),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                selected ? const Color(0xFF1C1C2A) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF8A8FA8)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      selected ? Colors.white : const Color(0xFF8A8FA8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Employee View ────────────────────────────────────────────────────────────

class _EmployeeView extends StatelessWidget {
  final dynamic user;
  final AppProvider provider;

  const _EmployeeView({required this.user, required this.provider});

  @override
  Widget build(BuildContext context) {
    // Demo stream for UI — replace with real loaded stream in production
    final demoStream = StreamModel(
      streamId: 1,
      sender: 'GEMPLOYER...',
      recipient: user?.publicKey,
      token: 'USDC',
      deposit: 500.0,
      ratePerSecond: 500.0 / (30 * 24 * 3600),
      startTime:
          DateTime.now().subtract(const Duration(days: 12)).millisecondsSinceEpoch ~/
              1000,
      stopTime:
          DateTime.now().add(const Duration(days: 18)).millisecondsSinceEpoch ~/
              1000,
      withdrawnAmount: 14.85,
      remainingBalance: 485.15,
      isActive: true,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Account pill ───────────────────────────────────────────────────
        if (user != null)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: user!.publicKey));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Public key copied')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1C1C2A)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B21B6).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline,
                        color: Color(0xFFA78BFA), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user!.email,
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        Text(user!.shortPublicKey,
                            style: GoogleFonts.spaceMono(
                                color: const Color(0xFF8A8FA8),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.copy_outlined,
                      color: Color(0xFF8A8FA8), size: 16),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: 20),

        // ── Live earning ticker card ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F1A12), Color(0xFF0C0C14)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF00D37F).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Streaming Now',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF8A8FA8), fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D37F).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00D37F),
                            shape: BoxShape.circle,
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat())
                            .fadeOut(duration: 800.ms)
                            .fadeIn(duration: 800.ms),
                        const SizedBox(width: 6),
                        Text('LIVE',
                            style: GoogleFonts.spaceMono(
                                fontSize: 10,
                                color: const Color(0xFF00D37F),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Available to Collect',
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              LiveEarningsTicker(
                ratePerSecond: demoStream.ratePerSecond,
                initialEarned: demoStream.availableToWithdraw(DateTime.now()),
              ),
              const SizedBox(height: 4),
              Text(
                'Rate: ${(demoStream.ratePerSecond * 3600).toStringAsFixed(4)} USDC/hr  ·  ${(demoStream.ratePerSecond * 86400).toStringAsFixed(2)} USDC/day',
                style: GoogleFonts.spaceMono(
                    color: const Color(0xFF8A8FA8), fontSize: 11),
              ),
              const SizedBox(height: 20),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: demoStream.progressFraction(DateTime.now()),
                  backgroundColor: const Color(0xFF1C1C2A),
                  color: const Color(0xFF00D37F),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Day ${DateTime.now().difference(demoStream.startDate).inDays} of 30',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF8A8FA8), fontSize: 11),
                  ),
                  Text(
                    'Total: 500 USDC',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF8A8FA8), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Collect Earnings',
                onTap: () async {
                  final txHash = await provider.withdraw(demoStream);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(txHash != null
                            ? 'Collected! Tx: ${txHash.substring(0, 8)}…'
                            : 'Nothing available to collect yet'),
                        backgroundColor: const Color(0xFF00D37F),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),

        const SizedBox(height: 16),

        // ── Stream cards ──────────────────────────────────────────────────
        StreamCard(stream: demoStream, onWithdraw: () {}),
      ],
    );
  }
}

// ─── Employer View ────────────────────────────────────────────────────────────

class _EmployerView extends StatelessWidget {
  final AppProvider provider;

  const _EmployerView({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // CTA card
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
                Text('Create a Salary Stream',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'Lock USDC into a Soroban stream. Your employee gets paid by the second — automatically, no chasing required.',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF8A8FA8), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'New Stream →',
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EmployerScreen()),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 16),

          // Feature tiles
          Row(
            children: [
              Expanded(
                child: _FeatureTile(
                  icon: Icons.timer_outlined,
                  label: 'Per-Second',
                  sub: 'Accrues every second',
                  color: const Color(0xFF00D37F),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FeatureTile(
                  icon: Icons.local_gas_station_outlined,
                  label: 'Gasless',
                  sub: 'fee_bump covers all fees',
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FeatureTile(
                  icon: Icons.mail_outline,
                  label: 'Email-Only',
                  sub: 'No wallet needed',
                  color: const Color(0xFF5B21B6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FeatureTile(
                  icon: Icons.cancel_outlined,
                  label: 'Cancellable',
                  sub: 'Pro-rata refund any time',
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;

  const _FeatureTile(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub,
              style: GoogleFonts.inter(
                  color: const Color(0xFF8A8FA8), fontSize: 11)),
        ],
      ),
    );
  }
}
