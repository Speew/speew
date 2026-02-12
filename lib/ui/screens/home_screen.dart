import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserName();
    });
  }

  Future<void> _checkUserName() async {
    final settingsProvider = context.read<SettingsProvider>();
    if (settingsProvider.userName.isEmpty) {
      _showUserNameDialog();
    } else {
      await _initializeConnection(settingsProvider.userName);
    }
  }

  Future<void> _initializeConnection(String userName) async {
    final connectionProvider = context.read<ConnectionProvider>();
    if (!connectionProvider.isInitialized) {
      await connectionProvider.initialize(userName);
    }
  }

  Future<void> _showUserNameDialog() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Your Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Your Name'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final userName = nameController.text.trim();
                if (userName.isNotEmpty) {
                  final settingsProvider = context.read<SettingsProvider>();
                  await settingsProvider.setUserName(userName);
                  await _initializeConnection(userName);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speew - P2P Messaging'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ConnectionProvider>().startDiscovery();
            },
          ),
        ],
      ),
      body: Consumer<ConnectionProvider>(
        builder: (context, provider, child) {
          if (!provider.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          final peers = provider.peers;

          if (peers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No peers found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Make sure other devices are nearby', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: peers.length,
            itemBuilder: (context, index) {
              final peer = peers[index];

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: peer.isConnected ? Colors.green : Colors.grey,
                  child: Text(peer.name.isNotEmpty ? peer.name[0].toUpperCase() : '', style: const TextStyle(color: Colors.white)),
                ),
                title: Text(peer.name),
                subtitle: Text(peer.isConnected ? 'Connected' : 'Last seen: ${_formatTime(peer.lastSeen)}'),
                trailing: peer.isConnected ? const Icon(Icons.circle, color: Colors.green, size: 12) : null,
                onTap: () {
                  if (peer.isConnected) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(peer: peer)));
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
