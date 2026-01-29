import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../core/app_config.dart';

class MeshStatisticsScreen extends StatelessWidget {
  const MeshStatisticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas Mesh'),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (!chatProvider.isMeshEnabled) {
            return _buildMeshDisabled();
          }

          final stats = chatProvider.getMeshStatistics();
          return _buildMeshStats(stats);
        },
      ),
    );
  }

  Widget _buildMeshDisabled() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.info_outline,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Mesh Multi-hop não está ativado',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ative nas configurações iniciais',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeshStats(Map<String, dynamic> stats) {
    final nodeId = stats['node_id'] as String?;
    final routesCount = stats['routes_count'] as int? ?? 0;
    final pendingPackets = stats['pending_packets'] as int? ?? 0;
    final cacheSize = stats['processed_cache_size'] as int? ?? 0;
    final routes = stats['routes'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      children: [
        // Node Info
        _buildInfoCard(
          'Informações do Nó',
          [
            _buildInfoRow('Node ID', nodeId ?? 'N/A'),
            _buildInfoRow('Rotas Conhecidas', '$routesCount'),
            _buildInfoRow('Pacotes Pendentes', '$pendingPackets'),
            _buildInfoRow('Cache de Processados', '$cacheSize'),
          ],
        ),

        const SizedBox(height: 16),

        // Routing Table
        _buildRoutingTable(routes),

        const SizedBox(height: 16),

        // Legend
        _buildLegend(),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeMedium,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutingTable(List<dynamic> routes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tabela de Rotas',
              style: TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            if (routes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Nenhuma rota conhecida',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...routes.map((route) => _buildRouteItem(route.toString())),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteItem(String route) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.route,
            size: 20,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              route,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeSmall,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Como Funciona',
              style: TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildLegendItem(
              Icons.router,
              'Mesh Multi-hop',
              'Mensagens podem ser retransmitidas através de até 5 dispositivos intermediários.',
            ),
            _buildLegendItem(
              Icons.trending_up,
              'Descoberta de Rotas',
              'O sistema descobre automaticamente as melhores rotas para cada destino.',
            ),
            _buildLegendItem(
              Icons.cached,
              'Cache Inteligente',
              'Pacotes já processados são descartados para evitar loops infinitos.',
            ),
            _buildLegendItem(
              Icons.timer,
              'TTL (Time To Live)',
              'Cada pacote tem vida útil de 5 hops para evitar sobrecarga da rede.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeSmall,
                    color: Colors.grey,
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
