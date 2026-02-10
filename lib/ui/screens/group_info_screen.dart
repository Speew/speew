import 'package:flutter/material.dart';
import '../../models/group.dart';

class GroupInfoScreen extends StatelessWidget {
  final Group group;

  const GroupInfoScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  child: const Text(
                    group.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  group.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('${group.memberIds.length} members'),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Members'),
            subtitle: const Text('${group.memberIds.length} members'),
          ),
        ],
      ),
    );
  }
}
