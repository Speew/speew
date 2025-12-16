import 'dart:async';
import '../utils/logger_service.dart';
import '../p2p/p2p_service.dart';
import '../models/peer.dart';
import '../reputation/reputation_core.dart';

/// Serviço responsável por monitorar a saúde da malha (mesh) e iniciar
/// processos de auto-cura (Auto-Healing) em caso de falhas ou churn (saída de nós).
class AutoHealingMeshService {
  final P2PService _p2pService;
  final ReputationCore _reputationCore;
  final Duration _healthCheckInterval = const Duration(seconds: 10);
  Timer? _healthCheckTimer;

  AutoHealingMeshService(this._p2pService, this._reputationCore);

  /// Inicia o monitoramento da malha.
  void startMonitoring() {
    if (_healthCheckTimer != null) return;

    logger.info('Iniciando monitoramento de Auto-Healing da malha.', tag: 'AutoHealing');
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      _performHealthCheck();
    });
  }

  /// Para o monitoramento da malha.
  void stopMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    logger.info('Monitoramento de Auto-Healing da malha parado.', tag: 'AutoHealing');
  }

  /// Executa a verificação de saúde e inicia a cura se necessário.
  void _performHealthCheck() {
    final connectedPeers = _p2pService.getConnectedPeers();
    final recentlyDroppedPeers = _p2pService.getRecentlyDroppedPeers();
    final totalPeers = connectedPeers.length + recentlyDroppedPeers.length;

    if (totalPeers == 0) return;

    // Churn Rate: Nós que caíram / Total de Nós (Conectados + Caídos)
    final churnRate = recentlyDroppedPeers.length / totalPeers;

    logger.debug('Peers conectados: ${connectedPeers.length}. Churn Rate: ${(churnRate * 100).toStringAsFixed(2)}%', tag: 'AutoHealing');

    // Critério de Sucesso Inegociável: Provar que a rede suporta churn de 20%
    if (churnRate >= 0.20) {
      logger.warn('ALERTA DE CHURN: Taxa de churn (${(churnRate * 100).toStringAsFixed(0)}%) atingiu ou excedeu 20%. Iniciando Auto-Healing Agressivo.', tag: 'AutoHealing');
      _aggressivelyHealMesh(recentlyDroppedPeers);
    } else if (recentlyDroppedPeers.isNotEmpty) {
      logger.info('Churn detectado, mas abaixo do limite. Iniciando Auto-Healing Suave.', tag: 'AutoHealing');
      _softHealMesh(recentlyDroppedPeers);
    }

    // Verificação de lentidão (parte do critério de otimização de gargalos)
    _checkSlowPeers(connectedPeers);
  }

  /// Tenta reconectar ou encontrar novas rotas para os nós perdidos.
  void _softHealMesh(List<Peer> droppedPeers) {
    for (final peer in droppedPeers) {
      logger.debug('Tentando reconectar com o peer perdido: ${peer.id}', tag: 'AutoHealing');
      _p2pService.tryReconnect(peer.id);
    }
  }

  /// Inicia uma re-propagação de rotas e reavaliação de vizinhos.
  void _aggressivelyHealMesh(List<Peer> droppedPeers) {
    logger.warn('Executando re-propagação de rotas e reavaliação de vizinhos.', tag: 'AutoHealing');
    _p2pService.forceRouteRecalculation();
    _p2pService.discoverNewPeers(count: droppedPeers.length * 2);
  }

  /// Verifica peers com latência alta e ajusta o Reputation Score.
  void _checkSlowPeers(List<Peer> connectedPeers) {
    for (final peer in connectedPeers) {
      final rs = _reputationCore.getReputationScore(peer.id);
      // Simulação: Se a latência for consistentemente alta (ex: > 500ms)
      if (rs != null && rs.latency > 500 && rs.score > 0.10) {
        logger.warn('Peer ${peer.id} detectado como lento (Latência: ${rs.latency}ms). Reduzindo score de reputação.', tag: 'AutoHealing');
        // Penalidade suave por lentidão
        _reputationCore.penalizePeer(peer.id, penaltyType: 'latency_degradation', amount: 0.05);
        _p2pService.markRouteAsSlow(peer.id); // Informa o P2PService para evitar rotas
      }
    }
  }

  void dispose() {
    _healthCheckTimer?.cancel();
  }
}
