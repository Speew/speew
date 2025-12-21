import 'package:flutter/material.dart';
import '../../core/models/user.dart';
import '../../features/marketplace/marketplace_service.dart';
import '../../features/marketplace/market_item.dart';
import '../../core/wallet/tokens/token_registry.dart';
import '../components/p2p_components.dart';
import '../components/app_button.dart';
import '../themes/app_theme.dart';

/// Tela principal do Marketplace P2P.
class MarketplaceScreen extends StatefulWidget {
  final User currentUser;

  const MarketplaceScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final MarketplaceService _marketplaceService = MarketplaceService();
  // Simulação de lista de itens
  final List<MarketItem> _items = [
    MarketItem(
      itemId: 'item1',
      sellerId: 'seller1',
      title: 'Serviço de Retransmissão Premium',
      description: 'Acesso a um nó de retransmissão de alta reputação por 1 mês.',
      price: 50.0,
      tokenId: TokenRegistry.MESH.id,
      listedDate: DateTime.now().subtract(Duration(days: 1)),
      requiredReputation: 80.0,
    ),
    MarketItem(
      itemId: 'item2',
      sellerId: 'seller2',
      title: 'Microtarefa: Teste de Rota',
      description: 'Teste a rota de 10 pacotes e reporte o resultado.',
      price: 5.0,
      tokenId: TokenRegistry.WORK.id,
      listedDate: DateTime.now().subtract(Duration(hours: 5)),
      requiredReputation: 50.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          return _buildItemCard(context, _items[index]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implementar CreateListingScreen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Criar listagem em desenvolvimento.')),
          );
        },
        icon: Icon(Icons.add_shopping_cart),
        label: Text('Listar Item'),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, MarketItem item) {
    final theme = Theme.of(context);
    final token = TokenRegistry.getTokenById(item.tokenId);
    
    return AppCard(
      onTap: () => _showItemDetails(context, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Text(
            item.description,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TokenBadge(
                amount: item.price,
                symbol: token?.symbol ?? 'TOKEN',
              ),
              AppButton(
                text: 'Comprar',
                onPressed: () => _buyItem(item),
                size: AppButtonSize.small,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showItemDetails(BuildContext context, MarketItem item) {
    // TODO: Implementar ItemDetailsScreen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Detalhes do item em desenvolvimento.')),
    );
  }

  void _buyItem(MarketItem item) async {
    try {
      await _marketplaceService.buyItem(
        buyerId: widget.currentUser.userId,
        item: item,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compra iniciada! Contrato leve criado para garantia.'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao comprar: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
