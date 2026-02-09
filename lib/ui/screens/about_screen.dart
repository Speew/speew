import 'package:flutter/material.dart';
import '../../core/app_config.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.security, size: 100),
          const SizedBox(height: 24),
          Text(
            AppConfig.appName,
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Version ${AppConfig.appVersion}',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Text(
            'Speew is a secure, decentralized messaging app that uses peer-to-peer connections and end-to-end encryption to protect your privacy.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
