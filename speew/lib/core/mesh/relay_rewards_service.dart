import 'dart:async';
import '../utils/logger_service.dart';
import '../wallet/economy_engine.dart';
import '../wallet/tokens/token_registry.dart';
import '../models/transaction.dart';
import '../cloud/fixed_node_client.dart'; // Para simular a verificação de FN

/// Serviço para gerenciar a recompensa de retransmissão (HOP++).
class RelayRewardsService {
  static const int _antiFraudLimitPerMinute = 100000; // Limite de bytes/minuto
  int _bytesRelayedInMinute = 0;
  late Timer _resetTimer;

  RelayRewardsService() {
    _resetTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _bytesRelayedInMinute = 0;
    });
  }

  /// Processa a recompensa por retransmissão de um pacote.
  Future<void> processRelayReward({
    required int packetSize,
    required int hops,
    required String relayPeerId,
  }) async {
    if (packetSize <= 0 || hops <= 0) return;

    // 1. Limite Anti-Fraude
    if (_bytesRelayedInMinute + packetSize > _antiFraudLimitPerMinute) {
      logger.warn('Limite anti-fraude atingido para $relayPeerId. Recompensa negada.', tag: 'RelayReward');
      return;
    }
    _bytesRelayedInMinute += packetSize;

    // 2. Recompensa baseada no tamanho
    double reward = packetSize * 0.00001; // Exemplo: 0.00001 HOP por byte

    // 3. Bônus para rotas longas (>= 3 hops)
    if (hops >= 3) {
      reward *= 1.2; // 20% de bônus
      logger.debug('Bônus de rota longa aplicado (Hops: $hops).', tag: 'RelayReward');
    }

    // 4. Penalidade para peers lentos (simulação)
    // TODO: Integrar com AutoHealingMeshService para verificar lentidão
    // if (isPeerSlow(relayPeerId)) {
    //   reward *= 0.8; // 20% de penalidade
    // }

    // 5. Ajuste final pelo Economy Engine (HOP++)
    reward += EconomyEngine.calculateHopReward(hops);

    if (reward > 0) {
      // Simulação de transação de recompensa
      final hopToken = TokenRegistry.getTokenBySymbol('HOP');
      if (hopToken != null) {
        // TODO: Implementar a criação de uma transação real de recompensa
      // 6. Multiplicador para Fixed Nodes (2.0x)
      if (isFixedNode(relayPeerId)) {
        reward *= 2.0; // 2.0x multiplicador para FNs
        logger.debug('Multiplicador FN (2.0x) aplicado a $relayPeerId.', tag: 'RelayReward');
      }

      // 7. User Charge (Opcional): Implementar a taxa simbólica aqui se o pacote foi roteado via FN
      // A lógica de cobrança deve ser integrada ao MultiPathEngine/FailoverController.
      // Por enquanto, apenas o multiplicador de recompensa é aplicado.
        logger.info('Recompensa HOP de ${reward.toStringAsFixed(4)} para $relayPeerId', tag: 'RelayReward');
      }
    }
  }

  // Simulação de verificação de Fixed Node (deve ser injetado ou verificado no Ledger)
  bool isFixedNode(String peerId) {
    // Lógica real: verificar se o peerId está registrado como FN no Ledger/Discovery Service
    // Por enquanto, simulamos que FNs têm um prefixo ou estão em uma lista.
    return peerId.startsWith('fn_'); 
  }

  void dispose() {
    _resetTimer.cancel();
  }
}
