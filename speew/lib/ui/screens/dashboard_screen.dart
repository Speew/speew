import 'package:flutter/material.dart';
import '../../core/models/user.dart';
import '../../core/p2p/p2p_service.dart';
import '../components/p2p_components.dart';
import 'chat_screen.dart';
import 'wallet_screen.dart';
import 'files_screen.dart';
import 'staking_screen.dart';
import 'marketplace_screen.dart';
import 'auction_screen.dart';
import 'reputation_dashboard_screen.dart';
import 'mesh_status_screen.dart';
import 'profile_screen.dart';
import 'mesh_graph_screen.dart';

/// Dashboard principal com navegação por tabs
class DashboardScreen extends StatefulWidget {
  final User currentUser;

  const DashboardScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final P2PService _p2pService = P2PService();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ChatScreen(currentUser: widget.currentUser),
      WalletScreen(currentUser: widget.currentUser),
      FilesScreen(currentUser: widget.currentUser),
      MeshStatusScreen(currentUser: widget.currentUser),
      ProfileScreen(currentUser: widget.currentUser),
      StakingScreen(currentUser: widget.currentUser),
      MarketplaceScreen(currentUser: widget.currentUser),
      AuctionScreen(currentUser: widget.currentUser),
      MeshGraphScreen(
        p2pService: P2PService(), // Simulação de injeção
        multiPathEngine: MultiPathEngine(P2PService()), // Simulação de injeção
      ),
      const ReputationDashboardScreen(), // Nova tela
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          // Status da rede
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: P2PStatusIndicator(
                isConnected: _p2pService.isServerRunning,
                connectedPeers: _p2pService.connectedPeers.length,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Arquivos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hub_outlined),
            activeIcon: Icon(Icons.hub),
            label: 'Rede',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          // Novos itens (acessíveis via navegação direta ou temporariamente aqui)
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_open_outlined),
            activeIcon: Icon(Icons.lock_open),
            label: 'Staking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Market',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel_outlined),
            activeIcon: Icon(Icons.gavel),
            label: 'Leilões',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.share_outlined),
            activeIcon: Icon(Icons.share),
            label: 'Mesh Graph',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.verified_user_outlined),
            activeIcon: Icon(Icons.verified_user),
            label: 'Reputação',
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Chat Mesh';
      case 1:
        return 'Wallet';
      case 5:
        return 'Staking';
      case 6:
        return 'Marketplace';
      case 7:
        return 'Leilões';
      case 2:
        return 'Arquivos';
      case 3:
        return 'Rede P2P';
      case 4:
        return 'Perfil';
      case 8:
        return 'Mesh Graph';
      case 9:
        return 'Reputação AI';
      default:
        return 'Rede P2P';
    }
  }
}
