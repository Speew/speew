import 'package:flutter/material.dart';
import '../../core/models/user.dart';
import '../../core/wallet/auction/auction_service.dart';
import '../../core/wallet/auction/auction_model.dart';
import '../../core/wallet/tokens/token_registry.dart';
import '../components/p2p_components.dart';
import '../components/app_button.dart';
import '../themes/app_theme.dart';

/// Tela principal do Sistema de Leilões Simbólicos.
class AuctionScreen extends StatefulWidget {
  final User currentUser;

  const AuctionScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> {
  final AuctionService _auctionService = AuctionService();
  // Simulação de lista de leilões
  final List<AuctionModel> _auctions = [
    AuctionModel(
      auctionId: 'auc1',
      initiatorId: 'seller1',
      title: 'Chave de Reputação Rara',
      description: 'Chave de reputação de um nó antigo da rede.',
      tokenId: TokenRegistry.MESH.id,
      startingPrice: 100.0,
      startTime: DateTime.now().subtract(Duration(hours: 1)),
      endTime: DateTime.now().add(Duration(hours: 2)),
      currentBid: 150.0,
      currentBidderId: 'bidder1',
    ),
    AuctionModel(
      auctionId: 'auc2',
      initiatorId: 'seller2',
      title: 'Pacote de WORK Credits',
      description: '100 WORK credits para microtarefas.',
      tokenId: TokenRegistry.WORK.id,
      startingPrice: 50.0,
      startTime: DateTime.now().subtract(Duration(minutes: 30)),
      endTime: DateTime.now().add(Duration(hours: 1)),
      currentBid: 50.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _auctions.length,
        itemBuilder: (context, index) {
          return _buildAuctionCard(context, _auctions[index]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implementar CreateAuctionScreen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Criar leilão em desenvolvimento.')),
          );
        },
        icon: Icon(Icons.gavel),
        label: Text('Novo Leilão'),
      ),
    );
  }

  Widget _buildAuctionCard(BuildContext context, AuctionModel auction) {
    final theme = Theme.of(context);
    final token = TokenRegistry.getTokenById(auction.tokenId);
    final timeLeft = auction.endTime.difference(DateTime.now());
    
    return AppCard(
      onTap: () => _showBidDialog(auction),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            auction.title,
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Text(
            auction.description,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lance Atual:',
                    style: theme.textTheme.bodySmall,
                  ),
                  TokenBadge(
                    amount: auction.currentBid,
                    symbol: token?.symbol ?? 'TOKEN',
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Tempo Restante:',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '${timeLeft.inHours}h ${timeLeft.inMinutes.remainder(60)}m',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBidDialog(AuctionModel auction) {
    final TextEditingController bidController = TextEditingController(
      text: (auction.currentBid + 0.01).toStringAsFixed(2),
    );
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Lance em ${auction.title}'),
          content: AppInput(
            label: 'Seu Lance',
            controller: bidController,
            keyboardType: TextInputType.number,
            hint: 'Mínimo: ${(auction.currentBid + 0.01).toStringAsFixed(2)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            AppButton(
              text: 'Fazer Lance',
              onPressed: () {
                Navigator.pop(context);
                _placeBid(auction, double.tryParse(bidController.text) ?? 0.0);
              },
              size: AppButtonSize.small,
            ),
          ],
        );
      },
    );
  }

  void _placeBid(AuctionModel auction, double bidAmount) async {
    try {
      final updatedAuction = await _auctionService.placeBid(
        auctionId: auction.auctionId,
        bidderId: widget.currentUser.userId,
        bidAmount: bidAmount,
      );
      
      // Atualiza a lista local (simulação)
      setState(() {
        final index = _auctions.indexWhere((a) => a.auctionId == auction.auctionId);
        if (index != -1) {
          _auctions[index] = updatedAuction;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lance de ${bidAmount.toStringAsFixed(2)} ${TokenRegistry.getTokenById(auction.tokenId)?.symbol} realizado com sucesso!'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao fazer lance: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
