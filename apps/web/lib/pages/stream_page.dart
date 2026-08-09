import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../services/api_service.dart';

class StreamPage extends ConsumerStatefulWidget {
  const StreamPage({super.key});

  @override
  ConsumerState<StreamPage> createState() => _StreamPageState();
}

class _StreamPageState extends ConsumerState<StreamPage> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _durationController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Stream')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _recipientController,
                decoration: const InputDecoration(labelText: 'Recipient Email'),
                validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount (USDC)'),
                keyboardType: TextInputType.number,
                validator: (v) => v != null && double.tryParse(v) != null ? null : 'Enter a valid amount',
              ),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(labelText: 'Duration (days)'),
                keyboardType: TextInputType.number,
                validator: (v) => v != null && int.tryParse(v) != null ? null : 'Enter a valid duration',
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Create Stream'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // TODO: Call Worker API to create stream
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stream created! (mock)')),
      );
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}
