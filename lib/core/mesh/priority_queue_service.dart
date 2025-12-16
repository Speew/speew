import '../../models/message.dart';
import '../reputation/reputation_core.dart';
import '../reputation/reputation_models.dart';
import 'dart:collection';

/// Nível de prioridade para propagação no mesh
enum MessagePriority {
  critical, // Transações simbólicas, atualizações de reputação, chaves públicas
  high,     // Identidades rotacionadas, estados sociais
  medium,   // Mensagens recentes, blocos de arquivos pequenos
  low,      // Arquivos gigantes, dados auxiliares
}

/// Item na fila de prioridade
class PriorityQueueItem {
  final String itemId;
  final MessagePriority priority;
  final DateTime timestamp;
  final int retryCount;
  final Map<String, dynamic> data;
  final String? destinationId;
  final String? sourcePeerId; // Novo campo para o nó de origem do pacote

  PriorityQueueItem({
    required this.itemId,
    required this.priority,
    required this.timestamp,
    this.retryCount = 0,
    required this.data,
    this.destinationId,
    this.sourcePeerId,
  });

  /// Calcula score de prioridade (maior = mais prioritário)
  double priorityScore(ReputationCore reputationCore) {
    // Base score por prioridade
    double baseScore = switch (priority) {
      MessagePriority.critical => 1000.0,
      MessagePriority.high => 500.0,
      MessagePriority.medium => 100.0,
      MessagePriority.low => 10.0,
    };
    
    // Penalidade por idade (itens mais antigos perdem prioridade gradualmente)
    final ageInSeconds = DateTime.now().difference(timestamp).inSeconds;
    final agePenalty = ageInSeconds * 0.01;
    
    // Penalidade por tentativas de reenvio
    final retryPenalty = retryCount * 10.0;

    // Multiplicador de Prioridade por Reputação (Regra: 1.2x para alta reputação)
    double reputationMultiplier = 1.0;
    if (sourcePeerId != null) {
      final rs = reputationCore.getReputationScore(sourcePeerId!)?.score ?? 0.5;
      // Nós de alta reputação (RS > 70% ou 0.7) ganham um multiplicador de 1.2x
      if (rs >= 0.7) {
        reputationMultiplier = 1.2;
      }
    }
    
    // O score final é a base ajustada pela reputação
    return (baseScore - agePenalty - retryPenalty) * reputationMultiplier;
  }

  PriorityQueueItem copyWith({
    String? itemId,
    MessagePriority? priority,
    DateTime? timestamp,
    int? retryCount,
    Map<String, dynamic>? data,
    String? destinationId,
    String? sourcePeerId,
  }) {
    return PriorityQueueItem(
      itemId: itemId ?? this.itemId,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      data: data ?? this.data,
      destinationId: destinationId ?? this.destinationId,
      sourcePeerId: sourcePeerId ?? this.sourcePeerId,
    );
  }
}

/// Serviço de Fila de Prioridade para Propagação Inteligente no Mesh
/// Reorganiza a fila de envio baseado em prioridades e reputação
class PriorityQueueService {
  static final PriorityQueueService _instance = PriorityQueueService._internal();
  factory PriorityQueueService() => _instance;
  PriorityQueueService._internal();

  final ReputationCore _reputationCore = ReputationCore(); // Dependência para cálculo de score

  /// Fila principal (ordenada por prioridade)
  final List<PriorityQueueItem> _queue = [];
  
  /// Itens em processamento
  final Set<String> _processingItems = {};
  
  /// Histórico de itens processados (últimos 1000)
  final Queue<String> _processedHistory = Queue<String>();
  static const int _maxHistorySize = 1000;
  
  /// Estatísticas de processamento
  final Map<MessagePriority, int> _processedCounts = {
    MessagePriority.critical: 0,
    MessagePriority.high: 0,
    MessagePriority.medium: 0,
    MessagePriority.low: 0,
  };

  // ==================== ADIÇÃO À FILA ====================

  /// Adiciona item à fila com prioridade
  void enqueue(PriorityQueueItem item) {
    // Verificar se já está na fila ou foi processado recentemente
    if (_isInQueue(item.itemId) || _wasRecentlyProcessed(item.itemId)) {
      return;
    }
    
    _queue.add(item);
    _sortQueue();
  }

  /// Adiciona transação simbólica (prioridade crítica)
  void enqueueTransaction({
    required String transactionId,
    required Map<String, dynamic> transactionData,
    String? destinationId,
  }) {
    enqueue(PriorityQueueItem(
      itemId: transactionId,
      priority: MessagePriority.critical,
      timestamp: DateTime.now(),
      data: transactionData,
      destinationId: destinationId,
    ));
  }

  /// Adiciona atualização de reputação (prioridade crítica)
  void enqueueReputationUpdate({
    required String updateId,
    required Map<String, dynamic> updateData,
  }) {
    enqueue(PriorityQueueItem(
      itemId: updateId,
      priority: MessagePriority.critical,
      timestamp: DateTime.now(),
      data: updateData,
    ));
  }

  /// Adiciona identidade rotacionada (prioridade alta)
  void enqueueIdentityRotation({
    required String rotationId,
    required Map<String, dynamic> rotationData,
  }) {
    enqueue(PriorityQueueItem(
      itemId: rotationId,
      priority: MessagePriority.high,
      timestamp: DateTime.now(),
      data: rotationData,
    ));
  }

  /// Adiciona estado social (prioridade alta)
  void enqueueSocialState({
    required String stateId,
    required Map<String, dynamic> stateData,
  }) {
    enqueue(PriorityQueueItem(
      itemId: stateId,
      priority: MessagePriority.high,
      timestamp: DateTime.now(),
      data: stateData,
    ));
  }

  /// Adiciona mensagem (prioridade média)
  void enqueueMessage({
    required String messageId,
    required Map<String, dynamic> messageData,
    String? destinationId,
  }) {
    enqueue(PriorityQueueItem(
      itemId: messageId,
      priority: MessagePriority.medium,
      timestamp: DateTime.now(),
      data: messageData,
      destinationId: destinationId,
    ));
  }

  /// Adiciona bloco de arquivo (prioridade baseada no tamanho)
  void enqueueFileBlock({
    required String blockId,
    required Map<String, dynamic> blockData,
    required int blockSize,
    String? destinationId,
  }) {
    // Blocos pequenos (< 128KB) = média, blocos grandes = baixa
    final priority = blockSize < 131072 
        ? MessagePriority.medium 
        : MessagePriority.low;
    
    enqueue(PriorityQueueItem(
      itemId: blockId,
      priority: priority,
      timestamp: DateTime.now(),
      data: blockData,
      destinationId: destinationId,
    ));
  }

  // ==================== REMOÇÃO DA FILA ====================

  /// Remove e retorna o item de maior prioridade
  PriorityQueueItem? dequeue() {
    if (_queue.isEmpty) return null;
    
    _sortQueue();
    final item = _queue.removeAt(0);
    
    _processingItems.add(item.itemId);
    return item;
  }

  /// Remove itens de baixa prioridade se a fila estiver cheia
  void trimLowPriorityItems({int maxQueueSize = 1000}) {
    if (_queue.length <= maxQueueSize) return;
    
    // Ordenar por prioridade
    _sortQueue();
    
    // Remover itens de menor prioridade
    final itemsToRemove = _queue.length - maxQueueSize;
    _queue.removeRange(_queue.length - itemsToRemove, _queue.length);
  }

  // ==================== GERENCIAMENTO DE PROCESSAMENTO ====================

  /// Marca item como processado com sucesso
  void markAsProcessed(String itemId, MessagePriority priority) {
    _processingItems.remove(itemId);
    
    // Adicionar ao histórico
    _processedHistory.addLast(itemId);
    if (_processedHistory.length > _maxHistorySize) {
      _processedHistory.removeFirst();
    }
    
    // Atualizar estatísticas
    _processedCounts[priority] = (_processedCounts[priority] ?? 0) + 1;
  }

  /// Marca item como falho e reenfileira com retry
  void markAsFailed(PriorityQueueItem item, {int maxRetries = 3}) {
    _processingItems.remove(item.itemId);
    
    if (item.retryCount < maxRetries) {
      // Reenfileirar com contador de retry incrementado
      final retriedItem = item.copyWith(
        retryCount: item.retryCount + 1,
        timestamp: DateTime.now(),
      );
      enqueue(retriedItem);
    }
  }

  /// Cancela processamento de um item
  void cancelProcessing(String itemId) {
    _processingItems.remove(itemId);
    _queue.removeWhere((item) => item.itemId == itemId);
  }

  // ==================== CONSULTAS ====================

  /// Retorna o tamanho da fila
  int get queueSize => _queue.length;

  /// Retorna número de itens em processamento
  int get processingCount => _processingItems.length;

  /// Verifica se a fila está vazia
  bool get isEmpty => _queue.isEmpty;

  /// Verifica se há itens críticos na fila
  bool get hasCriticalItems {
    return _queue.any((item) => item.priority == MessagePriority.critical);
  }

  /// Obtém próximo item sem remover da fila
  PriorityQueueItem? peek() {
    if (_queue.isEmpty) return null;
    _sortQueue();
    return _queue.first;
  }

  /// Obtém todos os itens de uma prioridade específica
  List<PriorityQueueItem> getItemsByPriority(MessagePriority priority) {
    return _queue.where((item) => item.priority == priority).toList();
  }

  /// Obtém estatísticas de processamento
  Map<String, dynamic> getStatistics() {
    return {
      'queue_size': queueSize,
      'processing_count': processingCount,
      'processed_counts': Map.from(_processedCounts),
      'critical_items': getItemsByPriority(MessagePriority.critical).length,
      'high_items': getItemsByPriority(MessagePriority.high).length,
      'medium_items': getItemsByPriority(MessagePriority.medium).length,
      'low_items': getItemsByPriority(MessagePriority.low).length,
    };
  }

  // ==================== FUNÇÕES AUXILIARES ====================

  /// Ordena a fila por score de prioridade (decrescente)
  void _sortQueue() {
    _queue.sort((a, b) => b.priorityScore(_reputationCore).compareTo(a.priorityScore(_reputationCore)));
  }

  /// Verifica se item está na fila
  bool _isInQueue(String itemId) {
    return _queue.any((item) => item.itemId == itemId) || 
           _processingItems.contains(itemId);
  }

  /// Verifica se item foi processado recentemente
  bool _wasRecentlyProcessed(String itemId) {
    return _processedHistory.contains(itemId);
  }

  /// Limpa a fila (para testes)
  void clear() {
    _queue.clear();
    _processingItems.clear();
    _processedHistory.clear();
    _processedCounts.clear();
  }

  /// Reseta estatísticas
  void resetStatistics() {
    _processedCounts.clear();
    for (final priority in MessagePriority.values) {
      _processedCounts[priority] = 0;
    }
  }
}
