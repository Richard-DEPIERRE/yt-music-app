import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/settings/settings_providers.dart';
import 'package:ytmusic/core/settings/settings_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _cidController = TextEditingController();
  final _csecretController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    _cidController.dispose();
    _csecretController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await ref.read(settingsRepositoryProvider).save(
            ApiConfigInput(
              baseUrl: _urlController.text.trim(),
              cfAccessClientId: _cidController.text.trim(),
              cfAccessClientSecret: _csecretController.text.trim(),
            ),
          );
      ref.invalidate(apiConfigProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Text(
                  'Enter your homelab backend URL and CF Access service '
                  'token credentials.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'required' : null,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://ytmusic.example.com',
                  ),
                ),
                TextFormField(
                  controller: _cidController,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'required' : null,
                  decoration: const InputDecoration(
                    labelText: 'CF-Access-Client-Id',
                  ),
                ),
                TextFormField(
                  controller: _csecretController,
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'required' : null,
                  decoration: const InputDecoration(
                    labelText: 'CF-Access-Client-Secret',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
