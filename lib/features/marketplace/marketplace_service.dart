import 'market_item.dart';
import '../../core/utils/logger_service.dart';
import '../../core/crypto/crypto_manager.dart';
import '../../core/storage/repository_pattern.dart';
import '../../core/wallet/contracts/contract_service.dart';
import '../../core/wallet/tokens/token_registry.dart';

/// Serviço para gerenciar o Marketplace P2P.
class MarketplaceService {
  final CryptoManager _cryptoManager = CryptoManager();
  final ContractService _contractService = ContractService();

  /// Cria um novo item para venda no marketplace.
  Future<MarketItem> createListing({
    required String sellerId,
    required String title,
    required String description,
    required double price,
    required String tokenId,
    double requiredReputation = 50.0,
  }) async {
    final item = MarketItem(
      itemId: _cryptoManager.generateUniqueId(),
      sellerId: sellerId,
      title: title,
      description: description,
      price: price,
      tokenId: tokenId,
      listedDate: DateTime.now(),
      requiredReputation: requiredReputation,
    );

    await repositories.marketItems.save(item);
    logger.info('Novo item listado: ${item.title}', tag: 'Marketplace');
    
    // TODO: Implementar anúncio no mesh via P2PService

    return item;
  }

  /// Compra um item, criando um contrato leve para garantir a transação.
  Future<void> buyItem({
    required String buyerId,
    required MarketItem item,
  }) async {
    // TODO: Implementar verificação de saldo e reputação do comprador

    // 1. Criar um contrato leve para garantir a entrega
    final contract = await _contractService.createContract(
      initiatorId: buyerId,
      counterpartyId: item.sellerId,
      tokenId: item.tokenId,
      value: item.price,
      condition: 'Entrega do item "${item.title}" e confirmação pelo comprador.',
      lockDuration: Duration(hours: 48), // 48h para entrega
      minReputationRequired: item.requiredReputation,
    );

    // 2. Bloquear o valor do comprador (implementado no ContractService)
    
    // 3. Simular a criação de uma MarketOrder
    final order = MarketOrder(
      orderId: _cryptoManager.generateUniqueId(),
      itemId: item.itemId,
      buyerId: buyerId,
      sellerId: item.sellerId,
      price: item.price,
      tokenId: item.tokenId,
      contractId: contract.contractId,
      orderDate: DateTime.now(),
    );

    await repositories.marketOrders.save(order);
    logger.info('Compra iniciada para item: ${item.title}. Contrato: ${contract.contractId}', tag: 'Marketplace');
  }

  /// Simulação de MarketOrder
  // TODO: Mover para um arquivo de modelo
  MarketOrder({
    required String orderId,
    required String itemId,
    required String buyerId,
    required String sellerId,
    required double price,
    required String tokenId,
    required String contractId,
    required DateTime orderDate,
  });
}
