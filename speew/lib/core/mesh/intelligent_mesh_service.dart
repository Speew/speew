import '../../core/utils/logger_service.dart';
import '../reputation/reputation_service.dart';
import '../storage/database_service.dart';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// ==================== NOVO MÓDULO: MESH INTELIGENTE ====================
/// Serviço de roteamento inteligente para rede mesh P2P
/// 
/// Funcionalidades:
/// - Priorização local baseada em reputação
/// - Evitar retransmissão por peers suspeitos
/// - Seleção de rotas com maior probabilidade de entrega
/// - Heurística armazenada localmente
///
/// ADICIONADO: Fase 3 - Expansão do projeto
class IntelligentMeshService extends ChangeNotifier {
  static final IntelligentMeshService _instance = IntelligentMeshService._internal();
  factory IntelligentMeshService() => _instance;
  IntelligentMeshService._internal();

  final DatabaseService _db = DatabaseService();
  final ReputationService _reputation = ReputationService();

  /// Histórico de rotas bem-sucedidas
  /// Map: destinationId -> List<routePath>
  final Map<String, List<List<String>>> _successfulRoutes = {};

  /// Histórico de falhas de roteamento
  /// Map: peerId -> failureCount
  final Map<String, int> _peerFailures = {};

  /// Latências médias por peer
  /// Map: peerId -> averageLatencyMs
  final Map<String, double> _peerLatencies = {};

  /// Confiabilidade de peers (taxa de sucesso)
  /// Map: peerId -> reliabilityScore (0.0 - 1.0)
  final Map<String, double> _peerReliability = {};

  /// Threshold de confiabilidade mínima para roteamento
  static const double _minReliabilityThreshold = 0.5;

  /// Threshold de reputação mínima para roteamento
  static const double _minReputationThreshold = 0.4;

  /// Número máximo de falhas antes de blacklist temporário
  static const int _maxFailuresBeforeBlacklist = 5;

  /// Duração do blacklist temporário
  static const Duration _blacklistDuration = Duration(minutes: 10);

  /// Peers em blacklist temporário
  final Map<String, DateTime> _blacklistedPeers = {};

  // ==================== SELEÇÃO INTELIGENTE DE ROTAS ====================

  /// Seleciona a melhor rota para um destino baseado em heurísticas
  Future<List<String>?> selectBestRoute(
    String destinationId,
    List<String> availablePeers,
  ) async {
    try {
      // Remove peers em blacklist
      final validPeers = await _filterBlacklistedPeers(availablePeers);
      
      if (validPeers.isEmpty) {
        logger.info('Nenhum peer válido disponível', tag: 'IntelligentMesh');
        return null;
      }

      // Verifica se há rotas bem-sucedidas anteriores para este destino
      if (_successfulRoutes.containsKey(destinationId)) {
        final historicalRoutes = _successfulRoutes[destinationId]!;
        
        // Tenta usar a rota mais recente que ainda tem peers disponíveis
        for (final route in historicalRoutes.reversed) {
          if (_isRouteAvailable(route, validPeers)) {
            logger.info('Usando rota histórica bem-sucedida', tag: 'IntelligentMesh');
            return route;
          }
        }
      }

      // Se não há histórico, calcula melhor rota baseada em heurísticas
      final bestRoute = await _calculateBestRoute(destinationId, validPeers);
      
      return bestRoute;
    } catch (e) {
      logger.info('Erro ao selecionar rota: $e', tag: 'IntelligentMesh');
      return null;
    }
  }

  /// Calcula a melhor rota baseada em múltiplas heurísticas
  Future<List<String>> _calculateBestRoute(
    String destinationId,
    List<String> availablePeers,
  ) async {
    // Calcula score para cada peer
    final peerScores = <String, double>{};
    
    for (final peerId in availablePeers) {
      final score = await _calculatePeerScore(peerId);
      peerScores[peerId] = score;
    }

    // Ordena peers por score (maior primeiro)
    final sortedPeers = peerScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Retorna rota com os melhores peers (até 3 hops)
    final route = sortedPeers
        .take(3)
        .map((e) => e.key)
        .toList();

    logger.info('Rota calculada: $route', tag: 'IntelligentMesh');
    return route;
  }

  /// Calcula score de um peer baseado em múltiplos fatores
  Future<double> _calculatePeerScore(String peerId) async {
    double score = 0.0;

    // Fator 1: Reputação (peso: 40%)
    final reputation = await _reputation.getReputation(peerId);
    score += reputation * 0.4;

    // Fator 2: Confiabilidade (peso: 30%)
    final reliability = _peerReliability[peerId] ?? 0.5;
    score += reliability * 0.3;

    // Fator 3: Latência (peso: 20%)
    final latency = _peerLatencies[peerId] ?? 1000.0;
    final latencyScore = 1.0 - (latency / 2000.0).clamp(0.0, 1.0);
    score += latencyScore * 0.2;

    // Fator 4: Histórico de falhas (peso: 10%)
    final failures = _peerFailures[peerId] ?? 0;
    final failureScore = 1.0 - (failures / _maxFailuresBeforeBlacklist).clamp(0.0, 1.0);
    score += failureScore * 0.1;

    return score;
  }

  /// Verifica se uma rota está disponível
  bool _isRouteAvailable(List<String> route, List<String> availablePeers) {
    return route.every((peerId) => availablePeers.contains(peerId));
  }

  /// Filtra peers em blacklist
  Future<List<String>> _filterBlacklistedPeers(List<String> peers) async {
    final now = DateTime.now();
    final validPeers = <String>[];

    for (final peerId in peers) {
      // Remove peers expirados do blacklist
      if (_blacklistedPeers.containsKey(peerId)) {
        final blacklistTime = _blacklistedPeers[peerId]!;
        if (now.difference(blacklistTime) > _blacklistDuration) {
          _blacklistedPeers.remove(peerId);
          logger.info('Peer $peerId removido do blacklist', tag: 'IntelligentMesh');
        } else {
          continue; // Ainda em blacklist
        }
      }

      // Verifica reputação mínima
      final reputation = await _reputation.getReputation(peerId);
      if (reputation < _minReputationThreshold) {
        logger.info('Peer $peerId filtrado por baixa reputação', tag: 'IntelligentMesh');
        continue;
      }

      // Verifica confiabilidade mínima
      final reliability = _peerReliability[peerId] ?? 0.5;
      if (reliability < _minReliabilityThreshold) {
        logger.info('Peer $peerId filtrado por baixa confiabilidade', tag: 'IntelligentMesh');
        continue;
      }

      validPeers.add(peerId);
    }

    return validPeers;
  }

  // ==================== FEEDBACK DE ROTEAMENTO ====================

  /// Registra sucesso de roteamento
  Future<void> recordRouteSuccess(
    String destinationId,
    List<String> route,
    int latencyMs,
  ) async {
    try {
      // Adiciona rota ao histórico de sucesso
      if (!_successfulRoutes.containsKey(destinationId)) {
        _successfulRoutes[destinationId] = [];
      }
      _successfulRoutes[destinationId]!.add(route);

      // Limita histórico a 10 rotas mais recentes
      if (_successfulRoutes[destinationId]!.length > 10) {
        _successfulRoutes[destinationId]!.removeAt(0);
      }

      // Atualiza métricas de cada peer na rota
      for (final peerId in route) {
        // Atualiza confiabilidade
        final currentReliability = _peerReliability[peerId] ?? 0.5;
        _peerReliability[peerId] = (currentReliability * 0.9) + (1.0 * 0.1);

        // Atualiza latência média
        final currentLatency = _peerLatencies[peerId] ?? latencyMs.toDouble();
        _peerLatencies[peerId] = (currentLatency * 0.8) + (latencyMs * 0.2);

        // Reseta contador de falhas
        _peerFailures[peerId] = 0;
      }

      logger.info('Sucesso registrado para rota: $route', tag: 'IntelligentMesh');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao registrar sucesso: $e', tag: 'IntelligentMesh');
    }
  }

  /// Registra falha de roteamento
  Future<void> recordRouteFailure(String peerId) async {
    try {
      // Incrementa contador de falhas
      _peerFailures[peerId] = (_peerFailures[peerId] ?? 0) + 1;

      // Atualiza confiabilidade negativamente
      final currentReliability = _peerReliability[peerId] ?? 0.5;
      _peerReliability[peerId] = (currentReliability * 0.9) + (0.0 * 0.1);

      // Verifica se deve adicionar ao blacklist
      if (_peerFailures[peerId]! >= _maxFailuresBeforeBlacklist) {
        _blacklistedPeers[peerId] = DateTime.now();
        logger.info('Peer $peerId adicionado ao blacklist', tag: 'IntelligentMesh');
      }

      logger.info('Falha registrada para peer: $peerId', tag: 'IntelligentMesh');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao registrar falha: $e', tag: 'IntelligentMesh');
    }
  }

  // ==================== PRIORIZAÇÃO DE MENSAGENS ====================

  /// Calcula prioridade de uma mensagem para roteamento
  Future<int> calculateMessagePriority(
    String senderId,
    String messageType,
  ) async {
    try {
      int priority = 5; // Prioridade base

      // Aumenta prioridade baseado na reputação do remetente
      final reputation = await _reputation.getReputation(senderId);
      if (reputation >= 0.8) {
        priority += 3;
      } else if (reputation >= 0.6) {
        priority += 2;
      } else if (reputation >= 0.4) {
        priority += 1;
      }

      // Ajusta prioridade baseado no tipo de mensagem
      switch (messageType) {
        case 'transaction':
          priority += 2; // Transações têm prioridade
          break;
        case 'file':
          priority -= 1; // Arquivos têm prioridade menor
          break;
        case 'text':
        default:
          // Mantém prioridade base
          break;
      }

      return priority.clamp(1, 10);
    } catch (e) {
      logger.info('Erro ao calcular prioridade: $e', tag: 'IntelligentMesh');
      return 5;
    }
  }

  /// Ordena mensagens por prioridade para roteamento
  Future<List<Map<String, dynamic>>> prioritizeMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final prioritizedMessages = <Map<String, dynamic>>[];

    for (final message in messages) {
      final senderId = message['sender_id'] as String;
      final messageType = message['type'] as String;
      final priority = await calculateMessagePriority(senderId, messageType);
      
      prioritizedMessages.add({
        ...message,
        'priority': priority,
      });
    }

    // Ordena por prioridade (maior primeiro)
    prioritizedMessages.sort((a, b) => 
      (b['priority'] as int).compareTo(a['priority'] as int)
    );

    return prioritizedMessages;
  }

  // ==================== ESTATÍSTICAS E DIAGNÓSTICO ====================

  /// Obtém estatísticas do mesh inteligente
  Map<String, dynamic> getMeshStats() {
    return {
      'successfulRoutesCount': _successfulRoutes.length,
      'totalPeersTracked': _peerReliability.length,
      'blacklistedPeers': _blacklistedPeers.length,
      'averageReliability': _calculateAverageReliability(),
      'averageLatency': _calculateAverageLatency(),
    };
  }

  /// Obtém estatísticas de um peer específico
  Map<String, dynamic> getPeerStats(String peerId) {
    return {
      'reliability': _peerReliability[peerId] ?? 0.5,
      'latency': _peerLatencies[peerId] ?? 0.0,
      'failures': _peerFailures[peerId] ?? 0,
      'isBlacklisted': _blacklistedPeers.containsKey(peerId),
    };
  }

  /// Calcula confiabilidade média da rede
  double _calculateAverageReliability() {
    if (_peerReliability.isEmpty) return 0.5;
    
    final sum = _peerReliability.values.reduce((a, b) => a + b);
    return sum / _peerReliability.length;
  }

  /// Calcula latência média da rede
  double _calculateAverageLatency() {
    if (_peerLatencies.isEmpty) return 0.0;
    
    final sum = _peerLatencies.values.reduce((a, b) => a + b);
    return sum / _peerLatencies.length;
  }

  /// Obtém lista de melhores peers
  Future<List<String>> getBestPeers(int count) async {
    final peerScores = <String, double>{};
    
    for (final peerId in _peerReliability.keys) {
      final score = await _calculatePeerScore(peerId);
      peerScores[peerId] = score;
    }

    final sortedPeers = peerScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPeers.take(count).map((e) => e.key).toList();
  }

  // ==================== LIMPEZA E MANUTENÇÃO ====================

  /// Limpa dados antigos e otimiza estruturas
  void performMaintenance() {
    final now = DateTime.now();

    // Remove peers expirados do blacklist
    _blacklistedPeers.removeWhere((peerId, blacklistTime) {
      return now.difference(blacklistTime) > _blacklistDuration;
    });

    // Reseta contadores de falhas muito altos
    _peerFailures.forEach((peerId, failures) {
      if (failures > _maxFailuresBeforeBlacklist * 2) {
        _peerFailures[peerId] = _maxFailuresBeforeBlacklist;
      }
    });

    // Limita tamanho do histórico de rotas
    _successfulRoutes.forEach((destinationId, routes) {
      if (routes.length > 10) {
        _successfulRoutes[destinationId] = routes.sublist(routes.length - 10);
      }
    });

    logger.info('Manutenção realizada', tag: 'IntelligentMesh');
    notifyListeners();
  }

  /// Limpa todos os dados do mesh inteligente
  void clearAllData() {
    _successfulRoutes.clear();
    _peerFailures.clear();
    _peerLatencies.clear();
    _peerReliability.clear();
    _blacklistedPeers.clear();
    
    logger.info('Todos os dados limpos', tag: 'IntelligentMesh');
    notifyListeners();
  }
}
