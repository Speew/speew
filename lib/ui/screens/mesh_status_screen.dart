import 'package:flutter/material.dart';
import '../../core/models/user.dart';
import '../../core/p2p/p2p_service.dart';
import '../../core/config/app_config.dart';
import '../themes/app_theme.dart';
import '../components/p2p_components.dart';

/// Tela de status da rede mesh
class MeshStatusScreen extends StatefulWidget {
  final User currentUser;

  const MeshStatusScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<MeshStatusScreen> createState() => _MeshStatusScreenState();
}

class _MeshStatusScreenState extends State<MeshStatusScreen> {
  final P2PService _p2pService = P2PService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = _p2pService.isServerRunning;
    final peersCount = _p2pService.connectedPeers.length;
    
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Status geral
        AppCard(
          child: Column(
            children: [
              Icon(
                isConnected ? Icons.check_circle : Icons.error_outline,
                size: 64,
                color: isConnected ? AppTheme.success : AppTheme.error,
              ),
              SizedBox(height: 16),
              Text(
                isConnected ? 'Rede Ativa' : 'Rede Inativa',
                style: theme.textTheme.displaySmall,
              ),
              SizedBox(height: 8),
              Text(
                isConnected
                    ? '$peersCount ${peersCount == 1 ? 'peer conectado' : 'peers conectados'}'
                    : 'Nenhum peer conectado',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
        
        // Métricas
        SizedBox(height: 16),
        Text(
          'Métricas da Rede',
          style: theme.textTheme.titleLarge,
        ),
        SizedBox(height: 12),
        
        _buildMetricCard(
          context,
          'Máximo de Hops',
          '${AppConfig.maxHops}',
          Icons.route,
          AppTheme.info,
        ),
        
        _buildMetricCard(
          context,
          'Perda Máxima',
          '${(AppConfig.maxPacketLoss * 100).toStringAsFixed(0)}%',
          Icons.signal_cellular_alt,
          AppTheme.warning,
        ),
        
        _buildMetricCard(
          context,
          'Conexões Máximas',
          '${AppConfig.maxConnections}',
          Icons.people,
          AppTheme.success,
        ),
        
        // Peers conectados
        if (peersCount > 0) ...[
          SizedBox(height: 24),
          Text(
            'Peers Conectados',
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _p2pService.connectedPeers.map((peer) {
              return MeshNodeBubble(
                nodeId: peer.peerId,
                displayName: peer.displayName,
                isOnline: true,
                hops: 0,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
