// rede_p2p_refactored/rede_p2p_refactored/lib/core/reputation/reputation_core.dart

import 'dart:async';
import 'package:rede_p2p_refactored/core/utils/logger_service.dart';
import 'package:rede_p2p_refactored/core/reputation/reputation_models.dart';
import 'package:rede_p2p_refactored/core/reputation/slashing_engine.dart';
import 'package:rede_p2p_refactored/core/wallet/economy_engine.dart';

/// O motor central que monitora, pontua e gerencia a reputação dos nós.
class ReputationCore {
  final LoggerService _logger = LoggerService('ReputationCore');
  final SlashingEngine _slashingEngine = SlashingEngine();
  final Map<String, ReputationScore> _reputationScores = {};
  final StreamController<ReputationScore> _scoreUpdateController = StreamController.broadcast();

  Stream<ReputationScore> get scoreUpdates => _scoreUpdateController.stream;

  ReputationCore();

  /// Inicializa o monitoramento e carrega scores persistidos.
  Future<void> initialize() async {
    _logger.info('Iniciando Reputation Core...');
    // TODO: Carregar scores persistidos do DatabaseService
    _logger.info('Reputation Core iniciado. ${ _reputationScores.length} scores carregados.');
  }

  /// Monitora o comportamento dos peers vizinhos e registra eventos.
  void monitorBehavior(ReputationEvent event) {
    _logger.debug('Evento de reputação recebido: ${event.metric} para ${event.peerId}');
    
    // 1. Registrar o evento (para cálculo futuro)
    // TODO: Persistir o evento em um banco de dados de eventos de comportamento.

    // 2. Recalcular o Reputation Score (RS)
    final newScore = _calculateReputationScore(event.peerId);
    
    // 3. Verificar e aplicar punição
    _slashingEngine.checkAndApplyPunishment(newScore);

    // 4. Notificar listeners
    _scoreUpdateController.add(newScore);
  }

  /// Calcula o Reputation Score (RS) para um nó conhecido.
  /// Implementa o Algoritmo de Pontuação por Comportamento (Score).
  ReputationScore _calculateReputationScore(String peerId) {
    // Obtém o score atual ou cria um novo
    final currentScore = _reputationScores.putIfAbsent(
      peerId,
      () => ReputationScore(peerId: peerId, lastUpdated: DateTime.now()),
    );

    // 1. Obter os pesos dinâmicos do Economy Engine
    final weights = EconomyEngine.getCurrentReputationWeights();

    // 2. Obter as pontuações normalizadas (N_i,j) para cada métrica
    // NOTE: Esta é uma simulação. Na implementação real, os dados viriam de um
    // serviço de monitoramento (ex: MeshService, P2PService).
    final Map<BehaviorMetric, double> normalizedScores = _getNormalizedScores(peerId);

    // 3. Calcular o novo Reputation Score (RS) usando a fórmula ponderada:
    // RS = Σ (N_i,j * W_j)
    double newScore = 0.0;
    weights.forEach((metric, weight) {
      final normalizedScore = normalizedScores[metric] ?? 0.5; // Default para 0.5 se não houver dados
      newScore += normalizedScore * weight;
    });

    // 4. Aplicar um fator de "decay" para que o score não seja estático
    // O novo score é uma média ponderada entre o score antigo e o novo cálculo.
    const double decayFactor = 0.1; // 10% do novo cálculo, 90% do score antigo
    currentScore.score = (currentScore.score * (1.0 - decayFactor) + newScore * decayFactor).clamp(0.0, 1.0);

    currentScore.lastUpdated = DateTime.now();
    _reputationScores[peerId] = currentScore;
    
    _logger.debug('Novo RS para $peerId: ${currentScore.score.toStringAsFixed(4)} (Baseado em $newScore)');
    return currentScore;
  }

  /// Simula a obtenção de pontuações normalizadas (0.0 a 1.0) para cada métrica.
  /// ESTE MÉTODO DEVE SER SUBSTITUÍDO POR CHAMADAS REAIS A SERVIÇOS DE MONITORAMENTO.
  Map<BehaviorMetric, double> _getNormalizedScores(String peerId) {
    // TODO: Implementar a lógica real de coleta de dados e normalização.
    // Por enquanto, retorna valores simulados para testes.
    return {
      BehaviorMetric.relaySuccessRate: 0.95, // Alto
      BehaviorMetric.latencyJitter: 0.80, // Bom
      BehaviorMetric.availabilityUptime: 0.99, // Excelente
      BehaviorMetric.packetForgeryAttempts: 0.0, // Nenhum
      BehaviorMetric.sybilDetectionScore: 1.0, // Não é Sybil
    };
  }

  /// Retorna o Reputation Score (RS) de um nó.
  ReputationScore? getReputationScore(String peerId) {
    return _reputationScores[peerId];
  }

  /// Compartilha e verifica pontuações com peers de alta reputação.
  Future<void> shareAndVerifyScores(String peerId, ReputationScore score) async {
    // TODO: Implementar lógica de consenso de reputação descentralizada.
    _logger.debug('Compartilhando e verificando RS para $peerId...');
  }

  /// Retorna uma lista dos 5 peers com melhor e pior RS.
  Map<String, List<ReputationScore>> getTopAndWorstPeers() {
    final sortedScores = _reputationScores.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return {
      'best': sortedScores.take(5).toList(),
      'worst': sortedScores.reversed.take(5).toList(),
    };
  }

  // TODO: Implementar o Engine de Moderação de Nós (Node Moderation Engine)
}
