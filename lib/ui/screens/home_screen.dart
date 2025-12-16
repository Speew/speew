import '../../services/network/p2p_service.dart';
import 'chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'reputation_screen.dart';
import 'wallet_screen.dart';
import 'energy_settings_screen.dart';

/// Tela inicial do aplicativo
/// Permite ativar servidor, buscar dispositivos e ver conexões ativas
class HomeScreen extends StatefulWidget {
  final String userId;
  final String displayName;

  const HomeScreen({
    Key? key,
    required this.userId,
    required this.displayName,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late P2PService _p2pService;

  @override
  void initState() {
    super.initState();
    _p2pService = P2PService();
    _initializeP2P();
  }

  /// Inicializa o serviço P2P
  Future<void> _initializeP2P() async {
    try {
      await _p2pService.initialize();
    } catch (e) {
      _showError('Erro ao inicializar P2P: $e');
    }
  }

  /// Ativa/desativa o servidor P2P
  Future<void> _toggleServer() async {
    try {
      if (_p2pService.isServerRunning) {
        await _p2pService.stopServer();
        _showSuccess('Servidor desativado');
      } else {
        await _p2pService.startServer(widget.userId, widget.displayName);
        _showSuccess('Servidor ativado');
      }
    } catch (e) {
      _showError('Erro ao alternar servidor: $e');
    }
  }

  /// Inicia/para a descoberta de dispositivos
  Future<void> _toggleDiscovery() async {
    try {
      if (_p2pService.isDiscovering) {
        await _p2pService.stopDiscovery();
        _showSuccess('Busca parada');
      } else {
        await _p2pService.startDiscovery();
        _showSuccess('Buscando dispositivos...');
      }
    } catch (e) {
      _showError('Erro ao buscar dispositivos: $e');
    }
  }

  /// Conecta a um peer descoberto
  Future<void> _connectToPeer(Peer peer) async {
    try {
      final success = await _p2pService.connectToPeer(peer);
      if (success) {
        _showSuccess('Conectado a ${peer.displayName}');
      } else {
        _showError('Falha ao conectar');
      }
    } catch (e) {
      _showError('Erro ao conectar: $e');
    }
  }

  /// Desconecta de um peer
  Future<void> _disconnectFromPeer(Peer peer) async {
    try {
      await _p2pService.disconnectFromPeer(peer.peerId);
      _showSuccess('Desconectado de ${peer.displayName}');
    } catch (e) {
      _showError('Erro ao desconectar: $e');
    }
  }

  /// Abre o chat com um peer
  void _openChat(Peer peer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          userId: widget.userId,
          peerId: peer.peerId,
          peerName: peer.displayName,
        ),
      ),
    );
  }

  /// Mostra mensagem de erro
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Mostra mensagem de sucesso
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _p2pService,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Speew'),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_balance_wallet),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WalletScreen(userId: widget.userId),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.star),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReputationScreen(userId: widget.userId),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              tooltip: 'Configurações de Energia',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EnergySettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Consumer<P2PService>(
          builder: (context, p2pService, child) {
            return Column(
              children: [
                // Painel de controle
                _buildControlPanel(p2pService),
                
                const Divider(),
                
                // Lista de conexões e dispositivos
                Expanded(
                  child: _buildDeviceList(p2pService),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Constrói o painel de controle
  Widget _buildControlPanel(P2PService p2pService) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status do usuário
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(widget.displayName),
              subtitle: Text('ID: ${widget.userId.substring(0, 8)}...'),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Botões de controle
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleServer,
                  icon: Icon(
                    p2pService.isServerRunning 
                      ? Icons.stop 
                      : Icons.play_arrow,
                  ),
                  label: Text(
                    p2pService.isServerRunning 
                      ? 'Parar Servidor' 
                      : 'Ativar Servidor',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p2pService.isServerRunning 
                      ? Colors.red 
                      : Colors.green,
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleDiscovery,
                  icon: Icon(
                    p2pService.isDiscovering 
                      ? Icons.stop 
                      : Icons.search,
                  ),
                  label: Text(
                    p2pService.isDiscovering 
                      ? 'Parar Busca' 
                      : 'Buscar Dispositivos',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p2pService.isDiscovering 
                      ? Colors.orange 
                      : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Constrói a lista de dispositivos
  Widget _buildDeviceList(P2PService p2pService) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Conectados', icon: Icon(Icons.link)),
              Tab(text: 'Descobertos', icon: Icon(Icons.devices)),
            ],
          ),
          
          Expanded(
            child: TabBarView(
              children: [
                // Lista de peers conectados
                _buildConnectedPeersList(p2pService),
                
                // Lista de peers descobertos
                _buildDiscoveredPeersList(p2pService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói a lista de peers conectados
  Widget _buildConnectedPeersList(P2PService p2pService) {
    if (p2pService.connectedPeers.isEmpty) {
      return const Center(
        child: Text('Nenhum dispositivo conectado'),
      );
    }

    return ListView.builder(
      itemCount: p2pService.connectedPeers.length,
      itemBuilder: (context, index) {
        final peer = p2pService.connectedPeers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.phone_android),
            ),
            title: Text(peer.displayName),
            subtitle: Text(
              '${peer.connectionType.toUpperCase()} • ${peer.signalStrength} dBm',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () => _openChat(peer),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _disconnectFromPeer(peer),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Constrói a lista de peers descobertos
  Widget _buildDiscoveredPeersList(P2PService p2pService) {
    if (!p2pService.isDiscovering && p2pService.discoveredPeers.isEmpty) {
      return const Center(
        child: Text('Inicie a busca para descobrir dispositivos'),
      );
    }

    if (p2pService.discoveredPeers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Buscando dispositivos...'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: p2pService.discoveredPeers.length,
      itemBuilder: (context, index) {
        final peer = p2pService.discoveredPeers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.phone_android),
            ),
            title: Text(peer.displayName),
            subtitle: Text(
              '${peer.connectionType.toUpperCase()} • ${peer.signalStrength} dBm',
            ),
            trailing: ElevatedButton(
              onPressed: () => _connectToPeer(peer),
              child: const Text('Conectar'),
            ),
          ),
        );
      },
    );
  }
}
