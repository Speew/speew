import 'dart:math';
import '../utils/logger_service.dart';
import '../p2p/p2p_service.dart';
import '../models/peer.dart';
import '../reputation/reputation_core.dart';
import '../reputation/reputation_models.dart';

/// Motor de Roteamento Multi-Path.
/// Responsável por enviar dados por múltiplos caminhos simultaneamente para resiliência e latência.
class MultiPathEngine {
  static const int _defaultMaxPaths = 3;
  static int _currentMaxPaths = _defaultMaxPaths;
  final ReputationCore _reputationCore = ReputationCore();
  final P2PService _p2pService;

  MultiPathEngine(this._p2pService);

  /// Envia a mensagem por até [maxPaths] rotas diferentes.
  Future<List<String>> sendMultiPath({
    required String destinationId,
    required String message,
    int maxPaths = _currentMaxPaths,
  }) async {
    // 1. Obter todas as rotas possíveis para o destino
    final allRoutes = _p2pService.findAllRoutes(destinationId);

    if (allRoutes.isEmpty) {
      logger.error('Nenhuma rota encontrada para $destinationId', tag: 'MultiPath');
      return [];
    }

    // 2. Selecionar as melhores rotas (ex: as mais curtas e com melhor reputação)
    
    // Regra: Nós com RS < 10% são completamente evitados (Blacklisted).
    const double blacklistThreshold = 0.10;
    
    final filteredRoutes = allRoutes.where((route) {
      // Verifica se algum nó na rota está na blacklist (RS < 10%)
      return !route.any((peer) {
        final rs = _reputationCore.getReputationScore(peer.id)?.score ?? 0.5; // Default para 0.5
        return rs < blacklistThreshold;
      });
    }).toList();

    if (filteredRoutes.isEmpty) {
      logger.warn('Nenhuma rota encontrada após filtragem por reputação (RS > 10%).', tag: 'MultiPath');
      return [];
    }

    // Regra: O Multi-Path Router deve priorizar caminhos que usam nós com RS > 70%.
    // Critério de ordenação: (Média do RS da rota) * 0.7 + (Inverso do Comprimento da Rota) * 0.3
    filteredRoutes.sort((routeA, routeB) {
      final scoreA = _calculateRouteScore(routeA);
      final scoreB = _calculateRouteScore(routeB);
      return scoreB.compareTo(scoreA); // Ordem decrescente (melhor score primeiro)
    });

    final selectedRoutes = filteredRoutes.take(maxPaths).toList();

    logger.info('Enviando mensagem por ${selectedRoutes.length} rotas selecionadas.', tag: 'MultiPath');

    // 3. Enviar em paralelo
    final results = await Future.wait(selectedRoutes.map((route) {
      // Simulação de envio por uma rota específica
      final nextHop = route.first;
      return _p2pService.sendData(
        peerId: nextHop.id,
        data: message,
        // Adicionar metadados para recombinação no destino
        metadata: {'multi_path_id': _generateMultiPathId(), 'total_paths': selectedRoutes.length},
      ).then((_) => 'Sucesso via ${route.map((p) => p.id).join('->')}')
       .catchError((e) => 'Falha via ${route.map((p) => p.id).join('->')}: $e');
    }));

    // 4. Simulação de recombinação no destino (lógica real estaria no P2PService do receptor)
    final successfulSends = results.where((r) => r.startsWith('Sucesso')).toList();
    
    if (successfulSends.isNotEmpty) {
      logger.debug('Recombinação simulada: ${successfulSends.length} de ${selectedRoutes.length} caminhos chegaram.', tag: 'MultiPath');
    } else {
      logger.warn('Nenhum caminho conseguiu entregar a mensagem.', tag: 'MultiPath');
    }

    return results;
  }

  /// Calcula um score ponderado para a rota, priorizando alta reputação e rotas curtas.
  double _calculateRouteScore(List<Peer> route) {
    if (route.isEmpty) return 0.0;

    // 1. Média do Reputation Score (RS) dos nós na rota
    final totalRS = route.fold<double>(0.0, (sum, peer) {
      return sum + (_reputationCore.getReputationScore(peer.id)?.score ?? 0.5);
    });
    final avgRS = totalRS / route.length;

    // 2. Inverso do Comprimento da Rota (prioriza rotas curtas)
    // Usamos 1.0 / (length + 1) para evitar divisão por zero e normalizar.
    final lengthInverse = 1.0 / (route.length + 1);

    // Ponderação: 70% Reputação, 30% Comprimento
    const double rsWeight = 0.7;
    const double lengthWeight = 0.3;

    return (avgRS * rsWeight) + (lengthInverse * lengthWeight);
  }

  String _generateMultiPathId() {
    return Random().nextInt(999999).toString();
  }

  /// Define o número máximo de caminhos.
  static void setMaxPaths(int max) {
    if (max < 1) {
      _currentMaxPaths = 1;
    } else {
      _currentMaxPaths = max;
    }
    logger.info('Número máximo de caminhos Multi-Path definido para: $_currentMaxPaths', tag: 'MultiPathEngine');
  }

  /// Reseta o número máximo de caminhos para o padrão.
  static void resetMaxPaths() {
    _currentMaxPaths = _defaultMaxPaths;
    logger.info('Número máximo de caminhos Multi-Path resetado para: $_currentMaxPaths', tag: 'MultiPathEngine');
  }
}
