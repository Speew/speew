import 'dart:async';
import 'dart:math';
import '../utils/logger_service.dart';

/// Serviço de Sincronização de Tempo da Mesh (Relógio Lógico de Lamport).
/// Garante um timestamp confiável e ordenado para o ledger e a economia.
class MeshTimeSyncService {
  int _lamportClock = 0;
  final Random _random = Random();
  late Timer _driftTimer;

  MeshTimeSyncService() {
    // Simula um pequeno "drift" para forçar a sincronização
    _driftTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _lamportClock += _random.nextInt(5); // Drift aleatório
    });
  }

  /// Retorna o timestamp lógico atual.
  int get currentLogicalTime => _lamportClock;

  /// Atualiza o relógio lógico com base em um evento interno.
  int tick() {
    _lamportClock++;
    return _lamportClock;
  }

  /// Atualiza o relógio lógico com base em um timestamp recebido de outro peer.
  int syncWithPeerTime(int peerTime) {
    _lamportClock = max(_lamportClock, peerTime) + 1;
    logger.debug('Relógio Lamport sincronizado. Novo tempo: $_lamportClock', tag: 'TimeSync');
    return _lamportClock;
  }

  /// Retorna um timestamp confiável para uso em transações.
  int getReliableTimestamp() {
    return tick(); // Usa o tick para garantir que o tempo sempre avance
  }

  void dispose() {
    _driftTimer.cancel();
  }
}
