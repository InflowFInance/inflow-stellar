import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../services/api_service.dart';

class ClaimPage extends ConsumerStatefulWidget {
  const ClaimPage({super.key});

  @override
  ConsumerState<ClaimPage> createState() => _ClaimPageState();
}

class _ClaimPageState extends ConsumerState<ClaimPage> {
  final _secretController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim Stream')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('Enter the secret from your payment link to claim the stream.'),
            const SizedBox(height: 24),
            TextField(
              controller: _secretController,
              decoration: const InputDecoration(labelText: 'Secret'),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _claim,
                    child: const Text('Claim Stream'),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _claim() async {
    final secret = _secretController.text.trim();
    if (secret.isEmpty) return;
    setState(() => _isLoading = true);
    // TODO: Call Worker API to claim stream
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stream claimed! (mock)')),
      );
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _secretController.dispose();
    super.dispose();
  }
}
