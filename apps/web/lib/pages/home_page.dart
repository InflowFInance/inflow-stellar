import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/api_service.dart';
import '../widgets/earnings_ticker.dart';
import 'stream_page.dart';
import 'claim_page.dart';

final emailProvider = StateProvider<String?>((ref) => null);
final publicKeyProvider = StateProvider<String?>((ref) => null);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(emailProvider);
    final publicKey = ref.watch(publicKeyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('inFlow for Stellar'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Get paid by the second.',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your salary streams in real time on Stellar.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            if (email != null && publicKey != null) ...[
              const EarningsTicker(),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StreamPage()),
                ),
                child: const Text('Create Stream'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ClaimPage()),
                ),
                child: const Text('Claim Stream'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () async {
                  final enteredEmail = await _showEmailDialog(context);
                  if (enteredEmail != null && context.mounted) {
                    final api = ApiService();
                    final result = await api.sendOtp(enteredEmail);
                    if (result['success'] == true && context.mounted) {
                      final code = await _showOtpDialog(context);
                      if (code != null) {
                        final verifyResult = await api.verifyOtp(enteredEmail, code);
                        if (verifyResult['verified'] == true && context.mounted) {
                          ref.read(emailProvider.notifier).state = enteredEmail;
                          ref.read(publicKeyProvider.notifier).state = verifyResult['publicKey'];
                        }
                      }
                    }
                  }
                },
                child: const Text('Connect Email'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<String?> _showEmailDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Email'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'you@example.com'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Send OTP'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showOtpDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter OTP'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '123456'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }
}
