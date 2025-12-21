import 'package:flutter/material.dart';

/// Enum para o estado do contrato simbólico.
enum ContractState {
  pending,
  active,
  fulfilled,
  failed,
  cancelled,
}

/// Modelo de dados para um Smart Contract Leve (Symbolic Contract).
class ContractModel {
  final String contractId;
  final String initiatorId;
  final String counterpartyId;
  final String tokenId;
  final double value;
  final String condition; // Descrição da condição de cumprimento
  final DateTime creationDate;
  final DateTime? expirationDate;
  ContractState state;
  final bool requiresDoubleSignature;
  final double minReputationRequired;

  ContractModel({
    required this.contractId,
    required this.initiatorId,
    required this.counterpartyId,
    required this.tokenId,
    required this.value,
    required this.condition,
    required this.creationDate,
    this.expirationDate,
    this.state = ContractState.pending,
    this.requiresDoubleSignature = true,
    this.minReputationRequired = 50.0,
  });

  // Verifica se o contrato está ativo e dentro do prazo.
  bool get isValid {
    if (state != ContractState.active) return false;
    if (expirationDate != null && DateTime.now().isAfter(expirationDate!)) {
      return false;
    }
    return true;
  }

  // Converte para JSON
  Map<String, dynamic> toJson() {
    return {
      'contractId': contractId,
      'initiatorId': initiatorId,
      'counterpartyId': counterpartyId,
      'tokenId': tokenId,
      'value': value,
      'condition': condition,
      'creationDate': creationDate.toIso8601String(),
      'expirationDate': expirationDate?.toIso8601String(),
      'state': state.name,
      'requiresDoubleSignature': requiresDoubleSignature,
      'minReputationRequired': minReputationRequired,
    };
  }

  // Factory para criar a partir de JSON
  factory ContractModel.fromJson(Map<String, dynamic> json) {
    return ContractModel(
      contractId: json['contractId'] as String,
      initiatorId: json['initiatorId'] as String,
      counterpartyId: json['counterpartyId'] as String,
      tokenId: json['tokenId'] as String,
      value: json['value'] as double,
      condition: json['condition'] as String,
      creationDate: DateTime.parse(json['creationDate'] as String),
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'] as String)
          : null,
      state: ContractState.values.byName(json['state'] as String),
      requiresDoubleSignature: json['requiresDoubleSignature'] as bool,
      minReputationRequired: json['minReputationRequired'] as double,
    );
  }
}
