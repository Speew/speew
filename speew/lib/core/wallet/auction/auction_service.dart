import 'auction_model.dart';
import '../../utils/logger_service.dart';
import '../../crypto/crypto_manager.dart';
import '../../storage/repository_pattern.dart';
import '../../errors/economy_exceptions.dart';

/// Serviço para gerenciar o Sistema de Leilões Simbólicos.
class AuctionService {
  final CryptoManager _cryptoManager = CryptoManager();

  /// Cria um novo leilão.
  Future<AuctionModel> createAuction({
    required String initiatorId,
    required String title,
    required String description,
    required String tokenId,
    required double startingPrice,
    required Duration duration,
  }) async {
    final now = DateTime.now();
    final auction = AuctionModel(
      auctionId: _cryptoManager.generateUniqueId(),
      initiatorId: initiatorId,
      title: title,
      description: description,
      tokenId: tokenId,
      startingPrice: startingPrice,
      startTime: now,
      endTime: now.add(duration),
      currentBid: startingPrice,
    );

    await repositories.auctions.save(auction);
    logger.info('Novo leilão criado: ${auction.title}', tag: 'Auction');
    
    // TODO: Implementar anúncio no mesh via P2PService

    return auction;
  }

  /// Faz um lance em um leilão.
  Future<AuctionModel> placeBid({
    required String auctionId,
    required String bidderId,
    required double bidAmount,
  }) async {
    final auction = await repositories.auctions.findById(auctionId);
    if (auction == null) {
      throw AuctionException.notFound(auctionId);
    }

    if (!auction.isActive || DateTime.now().isAfter(auction.endTime)) {
      throw AuctionException.inactive();
    }

    if (bidAmount <= auction.currentBid) {
      throw AuctionException.bidTooLow(auction.currentBid, bidAmount);
    }

    // TODO: Implementar verificação de saldo e bloqueio do valor do lance

    // Atualiza o leilão
    final updatedAuction = AuctionModel(
      auctionId: auction.auctionId,
      initiatorId: auction.initiatorId,
      title: auction.title,
      description: auction.description,
      tokenId: auction.tokenId,
      startingPrice: auction.startingPrice,
      startTime: auction.startTime,
      endTime: auction.endTime,
      currentBid: bidAmount,
      currentBidderId: bidderId,
      networkFee: auction.networkFee,
      isActive: auction.isActive,
    );

    await repositories.auctions.save(updatedAuction);
    logger.info('Novo lance de $bidAmount no leilão ${auction.title}', tag: 'Auction');
    
    // TODO: Implementar notificação no mesh

    return updatedAuction;
  }

  /// Encerra o leilão e processa a transação.
  Future<void> finalizeAuction(String auctionId) async {
    final auction = await repositories.auctions.findById(auctionId);
    if (auction == null) {
      throw AuctionException.notFound(auctionId);
    }

    if (auction.isActive && DateTime.now().isBefore(auction.endTime)) {
      throw AuctionException('Leilão ainda não terminou.');
    }

    if (auction.currentBidderId == null) {
      // Leilão sem lances
      auction.isActive = false;
      await repositories.auctions.save(auction);
      logger.info('Leilão ${auction.title} encerrado sem lances.', tag: 'Auction');
      return;
    }

    // Processar transação
    final winnerId = auction.currentBidderId!;
    final finalPrice = auction.currentBid;
    final feeAmount = finalPrice * auction.networkFee;
    final netAmount = finalPrice - feeAmount;

    // TODO: Implementar transferência do valor para o iniciador (netAmount)
    // TODO: Implementar distribuição da fee para a rede mesh (EconomyEngine)
    // TODO: Implementar liberação do item para o vencedor

    auction.isActive = false;
    await repositories.auctions.save(auction);
    logger.info('Leilão ${auction.title} finalizado. Vencedor: $winnerId, Preço: $finalPrice', tag: 'Auction');
  }
}
