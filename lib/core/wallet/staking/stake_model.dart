import 'package:flutter/material.dart';

/// Modelo de dados para representar um staking simbólico.
class StakeModel {
  final String stakeId;
  final String userId;
  final String tokenId;
  final double amount;
  final DateTime stakeDate;
  final Duration lockDuration;
  final double annualPercentageYield; // APY
  final double reputationBoost;
  bool isActive;

  StakeModel({
    required this.stakeId,
    required this.userId,
    required this.tokenId,
    required this.amount,
    required this.stakeDate,
    required this.lockDuration,
    required this.annualPercentageYield,
    this.reputationBoost = 0.0,
    this.isActive = true,
  });

  // Calcula o rendimento até o momento
  double calculateYield() {
    if (!isActive) return 0.0;
    final now = DateTime.now();
    final stakedDuration = now.difference(stakeDate);
    
    // Simples cálculo linear: (APY / 365 dias) * dias_staked * amount
    final daysStaked = stakedDuration.inDays;
    final dailyRate = annualPercentageYield / 365.0;
    
    return amount * dailyRate * daysStaked;
  }

  // Verifica se o período de bloqueio terminou
  bool isLockPeriodFinished() {
    return DateTime.now().isAfter(stakeDate.add(lockDuration));
  }

  // Converte para JSON
  Map<String, dynamic> toJson() {
    return {
      'stakeId': stakeId,
      'userId': userId,
      'tokenId': tokenId,
      'amount': amount,
      'stakeDate': stakeDate.toIso8601String(),
      'lockDurationSeconds': lockDuration.inSeconds,
      'annualPercentageYield': annualPercentageYield,
      'reputationBoost': reputationBoost,
      'isActive': isActive,
    };
  }

  // Factory para criar a partir de JSON
  factory StakeModel.fromJson(Map<String, dynamic> json) {
    return StakeModel(
      stakeId: json['stakeId'] as String,
      userId: json['userId'] as String,
      tokenId: json['tokenId'] as String,
      amount: json['amount'] as double,
      stakeDate: DateTime.parse(json['stakeDate'] as String),
      lockDuration: Duration(seconds: json['lockDurationSeconds'] as int),
      annualPercentageYield: json['annualPercentageYield'] as double,
      reputationBoost: json['reputationBoost'] as double,
      isActive: json['isActive'] as bool,
    );
  }
}
