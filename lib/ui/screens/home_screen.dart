import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final provider = context.read<ChatProvider>();
    
    if (!provider.isInitialized) {
      
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      final userName = 'User_${userId.substring(userId.length - 4)}';
      
      await provider.initialize(userId, userName);

      await provider.startDiscovery();
      await provider.startAdvertising();
    }
  }

  void _toggleDiscovery() {
    final provider = context.read<ChatProvider>();
    
    if (provider.isDiscovering) {
      provider.stopDiscovery();
    } else {
      provider.startDiscovery();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<ChatProvider>(
          builder: (context, provider, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Speew'),
                const Text(
                  provider.myName ?? 'Loading...',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          },
        ),
        actions: [
          Consumer<ChatProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: const Icon(
                  provider.isDiscovering ? Icons.search_off : Icons.search,
                  color: provider.isDiscovering ? Colors.green : null,
                ),
                onPressed: _toggleDiscovery,
                tooltip: provider.isDiscovering ? 'Stop Discovery' : 'Start Discovery',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          if (!provider.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final peers = provider.peers;

          if (peers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    provider.isDiscovering ? Icons.search : Icons.people_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    provider.isDiscovering ? 'Searching for peers...' : 'No peers found',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  if (!provider.isDiscovering)
                    ElevatedButton.icon(
                      onPressed: _toggleDiscovery,
                      icon: const Icon(Icons.search),
                      label: const Text('Start Discovery'),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: peers.length,
            itemBuilder: (context, index) {
              final peer = peers[index];
              final messages = provider.getMessages(peer.id);
              final lastMessage = messages.isNotEmpty ? messages.last : null;

              return ListTile(
                key: ValueKey(peer.id),
                leading: CircleAvatar(
                  backgroundColor: peer.isConnected ? Colors.green : Colors.grey,
                  child: const Text(
                    peer.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: const Text(peer.name),
                subtitle: const Text(
                  lastMessage?.content ?? (peer.isConnected ? 'Connected' : 'Tap to connect'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 12,
                      color: peer.isConnected ? Colors.green : Colors.grey,
                    ),
                    if (messages.isNotEmpty && !peer.isConnected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          messages.length.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                  ],
                ),
                onTap: () async {
                  if (!peer.isConnected) {
                    
                    final connected = await provider.connectToPeer(peer);
                    if (!connected) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: const Text('Failed to connect')),
                        );
                      }
                      return;
                    }
                  }

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(peer: peer),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          return FloatingActionButton(
            onPressed: _toggleDiscovery,
            tooltip: 'Toggle Discovery',
            child: const Icon(
              provider.isDiscovering ? Icons.stop : Icons.play_arrow,
            ),
          );
        },
      ),
    );
  }
}