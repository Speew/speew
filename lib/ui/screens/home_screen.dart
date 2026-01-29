import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/theme_provider.dart';
import '../../models/peer.dart';
import 'chat_screen.dart';
import 'mesh_stats_screen.dart';
import 'create_group_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speew MVP'),
        actions: [
          // Botão de estatísticas mesh (só aparece se mesh estiver ativo)
          Consumer<ChatProvider>(
            builder: (context, provider, _) {
              if (!provider.isMeshEnabled) return const SizedBox.shrink();
              
              return IconButton(
                icon: const Icon(Icons.router),
                tooltip: 'Estatísticas Mesh',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MeshStatisticsScreen(),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          return Column(
            children: [
              // Status bar
              if (chatProvider.statusMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade100,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          chatProvider.statusMessage!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Lista de peers
              Expanded(
                child: chatProvider.peers.isEmpty
                    ? _buildEmptyState()
                    : _buildPeerList(chatProvider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateGroupScreen(),
            ),
          );
        },
        tooltip: 'Criar Grupo',
        child: const Icon(Icons.group_add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Procurando dispositivos próximos...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Certifique-se de que Wi-Fi e Localização\nestão ativos',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPeerList(ChatProvider chatProvider) {
    return ListView.builder(
      itemCount: chatProvider.peers.length,
      itemBuilder: (context, index) {
        final peer = chatProvider.peers[index];
        return _buildPeerTile(peer, chatProvider);
      },
    );
  }

  Widget _buildPeerTile(Peer peer, ChatProvider chatProvider) {
    final messages = chatProvider.getMessagesForPeer(peer.id);
    final lastMessage = messages.isNotEmpty ? messages.last : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: peer.isConnected ? Colors.green : Colors.grey,
              child: Text(
                peer.name.isNotEmpty ? peer.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (peer.isConnected)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          peer.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lastMessage != null)
              Text(
                lastMessage.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 4),
            Text(
              peer.isConnected
                  ? 'Conectado'
                  : 'Último contato: ${_formatDate(peer.lastSeen)}',
              style: TextStyle(
                fontSize: 10,
                color: peer.isConnected ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
        trailing: peer.isConnected
            ? const Icon(Icons.chat, color: Colors.blue)
            : IconButton(
                icon: const Icon(Icons.link),
                onPressed: () {
                  chatProvider.connectToPeer(peer);
                },
              ),
        onTap: () {
          if (peer.isConnected) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(peer: peer),
              ),
            );
          } else {
            _showConnectDialog(peer);
          }
        },
        onLongPress: () => _showPeerOptions(peer),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    return '${diff.inDays}d atrás';
  }

  void _showConnectDialog(Peer peer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conectar'),
        content: Text('Deseja conectar a ${peer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatProvider>().connectToPeer(peer);
            },
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
  }

  void _showPeerOptions(Peer peer) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Remover peer'),
            onTap: () {
              Navigator.pop(context);
              _confirmRemovePeer(peer);
            },
          ),
          if (peer.isConnected)
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('Desconectar'),
              onTap: () {
                Navigator.pop(context);
                context.read<ChatProvider>().disconnectFromPeer(peer);
              },
            ),
        ],
      ),
    );
  }

  void _confirmRemovePeer(Peer peer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover peer'),
        content: Text(
          'Deseja remover ${peer.name}?\nTodo o histórico de mensagens será deletado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatProvider>().removePeer(peer.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _showRefreshDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Procurando dispositivos próximos...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sobre Speew MVP'),
        content: const Text(
          'Versão: 1.0.0\n\n'
          'App de mensagens P2P offline via Wi-Fi Direct.\n\n'
          'Features:\n'
          '• Descoberta de peers\n'
          '• Mensagens 1-para-1\n'
          '• Persistência local\n\n'
          'Desenvolvido como MVP funcional.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
