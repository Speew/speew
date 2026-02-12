import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                  child: Text(peer.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(peer.name),
                subtitle: Text(peer.isConnected ? 'Connected' : 'Last seen: ${_formatTime(peer.lastSeen)}'),
                trailing: peer.isConnected ? const Icon(Icons.circle, color: Colors.green, size: 12) : null,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(peer: peer)));
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
