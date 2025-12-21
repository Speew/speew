import 'package:flutter/material.dart';
import 'contract_model.dart';
import '../../utils/logger_service.dart';
import '../../crypto/crypto_manager.dart';
import '../../storage/repository_pattern.dart';
import '../../models/reputation.dart';
import '../tokens/token_registry.dart';
import '../../errors/economy_exceptions.dart';

/// Serviço para gerenciar Smart Contracts Leves (Symbolic Contracts).
class ContractService {
  final CryptoManager _cryptoManager = CryptoManager();

  /// Cria e inicia um novo contrato.
  Future<ContractModel> createContract({
    required String initiatorId,
    required String counterpartyId,
    required String tokenId,
    required double value,
    required String condition,
    Duration? lockDuration,
    double minReputationRequired = 50.0,
  }) async {
    final contract = ContractModel(
      contractId: _cryptoManager.generateUniqueId(),
      initiatorId: initiatorId,
      counterpartyId: counterpartyId,
      tokenId: tokenId,
      value: value,
      condition: condition,
      creationDate: DateTime.now(),
      expirationDate: lockDuration != null ? DateTime.now().add(lockDuration) : null,
      minReputationRequired: minReputationRequired,
    );

    // TODO: Implementar bloqueio do valor na WalletService

    await repositories.contracts.save(contract);
    logger.info('Contrato criado: ${contract.contractId}', tag: 'Contract');
    return contract;
  }

  /// Assina e ativa o contrato (requerido para multi-assinatura).
  Future<ContractModel> signContract(String contractId, String signerId) async {
    final contract = await repositories.contracts.findById(contractId);
    if (contract == null) {
      throw ContractException.notFound(contractId);
    }

    if (contract.state != ContractState.pending) {
      throw ContractException.invalidState(contract.state.name, ContractState.pending.name);
    }

    if (signerId != contract.counterpartyId) {
      throw Exception('Apenas a contraparte pode assinar.');
    }

    // TODO: Implementar verificação de reputação do signerId

    // Simulação de assinatura dupla
    contract.state = ContractState.active;
    await repositories.contracts.save(contract);
    logger.info('Contrato ${contract.contractId} ativado por assinatura dupla.', tag: 'Contract');
    return contract;
  }

  /// Cumpre o contrato e libera o valor.
  Future<ContractModel> fulfillContract(String contractId, String fulfillerId) async {
    final contract = await repositories.contracts.findById(contractId);
    if (contract == null) {
      throw ContractException.notFound(contractId);
    }

    if (contract.state != ContractState.active) {
      throw ContractException.invalidState(contract.state.name, ContractState.active.name);
    }

    // TODO: Implementar lógica de cumprimento (ex: verificar prova de trabalho)

    // Simulação de cumprimento
    contract.state = ContractState.fulfilled;
    
    // TODO: Implementar transferência do valor bloqueado para o destinatário

    await repositories.contracts.save(contract);
    logger.info('Contrato ${contract.contractId} cumprido.', tag: 'Contract');
    return contract;
  }

  /// Cancela o contrato e libera o valor bloqueado.
  Future<ContractModel> cancelContract(String contractId, String cancellerId) async {
    final contract = await repositories.contracts.findById(contractId);
    if (contract == null) {
      throw ContractException.notFound(contractId);
    }

    if (contract.state != ContractState.active && contract.state != ContractState.pending) {
      throw ContractException('Contrato não pode ser cancelado no estado ${contract.state.name}.');
    }

    // TODO: Implementar lógica de cancelamento (ex: disputa, reputação)

    // Simulação de cancelamento
    contract.state = ContractState.cancelled;
    
    // TODO: Implementar liberação do valor bloqueado para o iniciador

    await repositories.contracts.save(contract);
    logger.info('Contrato ${contract.contractId} cancelado.', tag: 'Contract');
    return contract;
  }
}
