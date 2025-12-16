import 'dart:collection';
import '../utils/logger_service.dart';
import '../p2p/p2p_service.dart';

/// Enumeração para definir a prioridade das mensagens.
enum MeshPriority {
  critical(4), // Contratos, pagamentos, keep-alives
  high(3),     // Mensagens de chat, comandos de rede
  medium(2),   // Marketplace, Staking, Leilões
  low(1);      // Arquivos grandes, logs, telemetria

  final int level;
  const MeshPriority(this.level);
}

/// Modelo de dados para um item na fila de despacho.
class MeshQueueItem {
  final String destinationId;
  final String data;
  final MeshPriority priority;
  final DateTime timestamp;

  MeshQueueItem({
    required this.destinationId,
    required this.data,
    required this.priority,
  }) : timestamp = DateTime.now();
}

/// Dispatcher que utiliza uma fila de prioridade para enviar mensagens.
class PriorityQueueMeshDispatcher {
  final P2PService _p2pService;
  // Fila de prioridade: ordena por nível de prioridade (maior primeiro) e depois por timestamp (FIFO)
  final PriorityQueue<MeshQueueItem> _queue = PriorityQueue((a, b) {
    if (a.priority.level != b.priority.level) {
      return b.priority.level.compareTo(a.priority.level); // Maior prioridade primeiro
    }
    return a.timestamp.compareTo(b.timestamp); // FIFO para mesma prioridade
  });

  PriorityQueueMeshDispatcher(this._p2pService);

  /// Adiciona uma mensagem à fila de despacho.
  void enqueue({
    required String destinationId,
    required String data,
    required MeshPriority priority,
  }) {
    final item = MeshQueueItem(
      destinationId: destinationId,
      data: data,
      priority: priority,
    );
    _queue.add(item);
    logger.debug('Mensagem enfileirada: Destino=$destinationId, Prioridade=${priority.name}', tag: 'Dispatcher');
    _processQueue();
  }

  /// Processa a fila de despacho, enviando o item de maior prioridade.
  void _processQueue() async {
    if (_queue.isEmpty) return;

    // Simulação de limite de envio para evitar sobrecarga
    if (_p2pService.isSendingLimitReached()) {
      logger.warn('Limite de envio atingido. Processamento da fila adiado.', tag: 'Dispatcher');
      return;
    }

    final item = _queue.removeFirst();
    logger.info('Despachando item de Prioridade ${item.priority.name} para ${item.destinationId}', tag: 'Dispatcher');

    try {
      // Simulação de envio real
      await _p2pService.sendData(
        peerId: item.destinationId,
        data: item.data,
        metadata: {'priority': item.priority.name},
      );
      logger.debug('Despacho bem-sucedido.', tag: 'Dispatcher');
    } catch (e) {
      logger.error('Falha no despacho: $e. Reenfileirando com prioridade reduzida.', tag: 'Dispatcher');
      // Reenfileira com prioridade reduzida (simulação)
      final newPriority = item.priority.level > 1 ? MeshPriority.values.firstWhere((p) => p.level == item.priority.level - 1) : MeshPriority.low;
      _queue.add(MeshQueueItem(
        destinationId: item.destinationId,
        data: item.data,
        priority: newPriority,
      ));
    }

    // Continua processando o próximo item
    // Adiciona um pequeno delay para simular o tempo de envio
    Future.delayed(Duration(milliseconds: 50), _processQueue);
  }

  /// Retorna o número de itens na fila.
  int get queueSize => _queue.length;
}
