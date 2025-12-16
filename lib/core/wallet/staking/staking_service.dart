import 'package:flutter/material.dart';
import 'stake_model.dart';
import '../../utils/logger_service.dart';
import '../../crypto/crypto_manager.dart';
import '../../storage/repository_pattern.dart';
import '../../models/reputation.dart';
import '../tokens/token_registry.dart';
import '../../errors/economy_exceptions.dart';

/// Serviço para gerenciar o staking simbólico.
class StakingService {
  final CryptoManager _cryptoManager = CryptoManager();

  /// Cria um novo staking.
  Future<StakeModel> stake({
    required String userId,
    required String tokenId,
    required double amount,
    required Duration lockDuration,
  }) async {
    final token = TokenRegistry.getTokenById(tokenId);
    if (token == null) {
      throw TokenException.notFound(tokenId);
    }

    // TODO: Implementar verificação de saldo na WalletService

    final stake = StakeModel(
      stakeId: _cryptoManager.generateUniqueId(),
      userId: userId,
      tokenId: tokenId,
      amount: amount,
      stakeDate: DateTime.now(),
      lockDuration: lockDuration,
      annualPercentageYield: _calculateAPY(lockDuration),
      reputationBoost: _calculateReputationBoost(amount, lockDuration),
    );

    // Salvar no repositório
    await repositories.stakes.save(stake);
    logger.info('Novo staking criado: ${stake.stakeId}', tag: 'Staking');
    
    // TODO: Implementar dedução do saldo do usuário

    return stake;
  }

  /// Remove um staking e retorna o valor + rendimento.
  Future<double> unstake(String stakeId) async {
    final stake = await repositories.stakes.findById(stakeId);
    if (stake == null) {
      throw Exception('Staking não encontrado.');
    }

    if (!stake.isLockPeriodFinished()) {
      throw StakingException.lockPeriodNotFinished();
    }

    final yieldAmount = stake.calculateYield();
    final totalReturn = stake.amount + yieldAmount;

    // Atualizar status
    stake.isActive = false;
    await repositories.stakes.save(stake);
    
    // TODO: Implementar adição do totalReturn ao saldo do usuário

    logger.info('Unstake realizado. Retorno total: $totalReturn', tag: 'Staking');
    return totalReturn;
  }

  /// Calcula o APY (Annual Percentage Yield) baseado na duração do bloqueio.
  double _calculateAPY(Duration lockDuration) {
    if (lockDuration.inDays >= 365) return 0.10; // 10% para 1 ano
    if (lockDuration.inDays >= 180) return 0.07; // 7% para 6 meses
    if (lockDuration.inDays >= 90) return 0.05; // 5% para 3 meses
    return 0.02; // 2% para menos
  }

  /// Calcula o bônus de reputação.
  double _calculateReputationBoost(double amount, Duration lockDuration) {
    // Bônus é proporcional ao valor e ao tempo de bloqueio
    return (amount * 0.001) + (lockDuration.inDays * 0.01);
  }

  /// Aplica o boost de reputação para o usuário.
  Future<void> applyReputationBoost(String userId) async {
    final activeStakes = await repositories.stakes.findByUserId(userId);
    final totalBoost = activeStakes.where((s) => s.isActive).fold<double>(
      0.0,
      (sum, stake) => sum + stake.reputationBoost,
    );

    // TODO: Integrar com ReputationService para aplicar o boost
    logger.debug('Total Reputation Boost para $userId: $totalBoost', tag: 'Staking');
  }
}
