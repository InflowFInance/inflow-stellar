import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final earningsProvider = StateProvider<double>((ref) => 0.0);

class EarningsTicker extends ConsumerWidget {
  const EarningsTicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(earningsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('Earned so far', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              '\$${earnings.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text('Streaming live...', style: TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
