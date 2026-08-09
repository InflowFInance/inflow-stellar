import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/gradient_button.dart';

/// Employer screen for creating a new salary stream.
class EmployerScreen extends StatefulWidget {
  const EmployerScreen({super.key});

  @override
  State<EmployerScreen> createState() => _EmployerScreenState();
}

class _EmployerScreenState extends State<EmployerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();
  int _durationDays = 30;
  bool _isSubmitting = false;
  String? _resultStreamId;

  @override
  void dispose() {
    _emailController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _createStream() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final provider = context.read<AppProvider>();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final now = DateTime.now();
    final start = now.add(const Duration(minutes: 5));
    final stop = start.add(Duration(days: _durationDays));

    try {
      final streamId = await provider.stellarService.createStream(
        tokenAddress: 'USDC_CONTRACT_ADDRESS', // TODO: set real USDC SAC
        depositUsdc: amount,
        startTime: start,
        stopTime: stop,
        recipientEmail: _emailController.text.trim(),
      );
      setState(() => _resultStreamId = streamId.toString());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C14),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('New Salary Stream',
            style: GoogleFonts.spaceGrotesk(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _resultStreamId != null
          ? _SuccessView(streamId: _resultStreamId!)
          : _FormView(
              formKey: _formKey,
              emailController: _emailController,
              amountController: _amountController,
              durationDays: _durationDays,
              isSubmitting: _isSubmitting,
              onDurationChanged: (d) => setState(() => _durationDays = d),
              onSubmit: _createStream,
            ),
    );
  }
}

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController amountController;
  final int durationDays;
  final bool isSubmitting;
  final ValueChanged<int> onDurationChanged;
  final VoidCallback onSubmit;

  const _FormView({
    required this.formKey,
    required this.emailController,
    required this.amountController,
    required this.durationDays,
    required this.isSubmitting,
    required this.onDurationChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final ratePreview = (double.tryParse(amountController.text) ?? 0) /
        (durationDays * 86400);

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Employee email
          _SectionLabel('Employee Email'),
          const SizedBox(height: 8),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: _inputDecoration('employee@company.com',
                icon: Icons.email_outlined),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 20),

          // Amount
          _SectionLabel('Total Salary (USDC)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(color: Colors.white),
            decoration:
                _inputDecoration('e.g. 500', icon: Icons.attach_money),
            onChanged: (_) => (context as Element).markNeedsBuild(),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Enter an amount > 0';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Duration
          _SectionLabel('Stream Duration: $durationDays days'),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFF59E0B),
              thumbColor: const Color(0xFFF59E0B),
              inactiveTrackColor: const Color(0xFF1C1C2A),
              overlayColor: const Color(0x33F59E0B),
            ),
            child: Slider(
              value: durationDays.toDouble(),
              min: 1,
              max: 365,
              divisions: 364,
              onChanged: (v) => onDurationChanged(v.round()),
            ),
          ),

          // Rate preview
          if ((double.tryParse(amountController.text) ?? 0) > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C14),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: const Color(0xFF00D37F).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _RateRow('Per second',
                      '${ratePreview.toStringAsFixed(8)} USDC'),
                  _RateRow(
                      'Per hour',
                      '${(ratePreview * 3600).toStringAsFixed(6)} USDC'),
                  _RateRow(
                      'Per day', '${(ratePreview * 86400).toStringAsFixed(4)} USDC'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          GradientButton(
            label: isSubmitting ? 'Creating Stream…' : 'Create Stream & Send Link',
            isLoading: isSubmitting,
            onTap: onSubmit,
          ),

          const SizedBox(height: 12),
          Text(
            '⚡ A secure payment link will be emailed to the recipient.\nNo wallet required on their end.',
            style: GoogleFonts.inter(
                color: const Color(0xFF8A8FA8), fontSize: 12, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF3C3C4A)),
      prefixIcon:
          icon != null ? Icon(icon, color: const Color(0xFF8A8FA8)) : null,
      filled: true,
      fillColor: const Color(0xFF0C0C14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1C1C2A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1C1C2A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
          color: const Color(0xFF8A8FA8),
          fontSize: 12,
          fontWeight: FontWeight.w500),
    );
  }
}

class _RateRow extends StatelessWidget {
  final String label;
  final String value;
  const _RateRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: const Color(0xFF8A8FA8), fontSize: 12)),
          Text(value,
              style: GoogleFonts.spaceMono(
                  color: const Color(0xFF00D37F), fontSize: 12)),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String streamId;
  const _SuccessView({required this.streamId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF00D37F).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF00D37F), size: 42),
            )
                .animate()
                .scale(begin: const Offset(0.5, 0.5), duration: 400.ms,
                    curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text('Stream Created!',
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Stream #$streamId is live.\nA payment link has been sent.',
                style: GoogleFonts.inter(
                    color: const Color(0xFF8A8FA8),
                    fontSize: 14,
                    height: 1.6),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Back to Dashboard',
                  style: GoogleFonts.inter(
                      color: const Color(0xFFF59E0B),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
