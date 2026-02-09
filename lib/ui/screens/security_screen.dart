import 'package:flutter/material.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('End-to-End Encryption'),
            subtitle: const Text('All messages are encrypted'),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text('Key Management'),
            subtitle: const Text('Manage encryption keys'),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off),
            title: const Text('Stealth Mode'),
            subtitle: const Text('Hide app from recent apps'),
          ),
        ],
      ),
    );
  }
}
