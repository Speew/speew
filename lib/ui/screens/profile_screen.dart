import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 60,
                  child: Text(
                    settings.userName.isNotEmpty
                        ? settings.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: const InputDecoration(labelText: 'Name'),
                controller: TextEditingController(text: settings.userName),
                onSubmitted: (value) => settings.setUserName(value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(labelText: 'Status'),
                controller: TextEditingController(text: settings.userStatus),
                onSubmitted: (value) => settings.setUserStatus(value),
              ),
            ],
          );
        },
      ),
    );
  }
}
