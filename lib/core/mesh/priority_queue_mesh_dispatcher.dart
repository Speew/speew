// ==================== STUBS E MOCKS PARA COMPILAÇÃO ====================
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';

// '../utils/logger_service.dart'
class LoggerService {
  void info(String message, {String? tag, dynamic error}) => print('[INFO][${tag ?? 'App'}] $message ${error ?? ''}');
  void warn(String message, {String? tag, dynamic error}) => print('[WARN][${tag ?? 'App'}] $message ${error ?? ''}');
  void error(String message, {String? tag, dynamic error}) => print('[ERROR][${tag ?? 'App'}] $message ${error ?? ''}');
  void debug(String message, {String? tag, dynamic error}) {
    if (kDebugMode) print('[DEBUG][${tag ?? 'App'}] $message ${error ?? ''}');
  }
}
final logger = LoggerService();

// Mock para jsonEncode (para a simulação de serialização)
// O import 'dart:convert' é necessário no arquivo original.
String jsonEncode(Object? object) {
  return '{"data": "mock_data", "type": "${(object is P2PMessage) ? object.contentType : 'unknown'}", "receiverId": "${(object is P2PMessage) ? object.receiverId : 'unknown'}"}';
}

// Modelos de Suporte
class User {
  final String id;
  User({required this.id});
}
class P2PMessage {
  final String messageId;
  final String receiverId;
  final String contentType;
  
  P2PMessage({required this.messageId, required this.receiverId, required this.contentType});

  Map<String, dynamic> toMap() => {
    'id': messageId,
    'receiver': receiverId,
    'type': contentType,
  };
}

// Stubs para Reputação
class ReputationScore {
  final double score; 
  ReputationScore({required this.score});
}
class ReputationCore {
  final Map<String, ReputationScore> _scores = {
    'sender-high': ReputationScore(score: 0.95),
    'sender-medium': ReputationScore(score: 0.60),
    'sender-low': ReputationScore(score: 0.20),
  };

  ReputationScore? getReputationScore(String peerId) {
    return _scores[peerId];
  }
}

// Stub para P2PService
class P2PService {
  Future<bool> sendData(
    String receiverId,
    String serializedData, {
    required MessagePriority priority,
    Map<String, dynamic>? metadata,
  }) async {
    final messageId = metadata?['messageId'] ?? 'unknown';
    // Simulação de bloqueio para teste
    if (priority == MessagePriority.BULK && serializedData.contains('sender-low')) {
      logger.warn('P2PService: Bloqueio simulado de BULK de baixa reputação. Mensagem $messageId.', tag: 'P2P');
      return false;
    }
    
    await Future.delayed(Duration(milliseconds: 50)); 
    logger.debug('P2PService: Mensagem $messageId enviada (Prioridade: $priority).', tag: 'P2P');
    return true;
  }
}

// ==================== PriorityQueueMeshDispatcher ====================

/// Enumeração para definir a prioridade de uma mensagem/pacote (QoS)
enum MessagePriority {
  CRITICAL, 
  REAL_TIME, 
  SYNC, 
  BULK, 
}

/// Mapeia o enum para um valor numérico de prioridade (maior = mais prioritário)
int _getPriorityValue(MessagePriority priority) {
  switch (priority) {
    case MessagePriority.CRITICAL:
      return 4;
    case MessagePriority.REAL_TIME:
      return 3;
    case MessagePriority.SYNC:
      return 2;
    case MessagePriority.BULK:
      return 1;
  }
}

/// Gerenciador de Despacho de Mensagens com Fila de Prioridade.
class PriorityQueueMeshDispatcher {
  final P2PService _p2pService;
  final ReputationCore _reputationCore;
  
  // Fila de prioridade: armazena mensagens a serem enviadas
  final PriorityQueue<_QueuedMessage> _messageQueue = PriorityQueue((a, b) {
    // 1. Prioridade principal: Tipo de Tráfego (QoS)
    final qosA = _getPriorityValue(a.priorityType);
    final qosB = _getPriorityValue(b.priorityType);
    
    if (qosA != qosB) {
      return qosB.compareTo(qosA); // Decrescente (Maior QoS primeiro)
    }
    
    // 2. Prioridade secundária: STT Score (Desempate)
    if (a.sttScore != b.sttScore) {
      return b.sttScore.compareTo(a.sttScore); // Decrescente (Maior Score primeiro)
    }
    
    // 3. Desempate final: FIFO (Menor timestamp primeiro)
    return a.timestamp.compareTo(b.timestamp);
  });
  

  static const int _maxQueueSize = 1000;
  static const int _maxConcurrentSends = 5;
  
  int _concurrentSends = 0;
  Timer? _dispatchTimer;

  PriorityQueueMeshDispatcher(this._p2pService, this._reputationCore) {
    _startDispatching();
  }

  /// Adiciona uma mensagem à fila de despacho.
  bool enqueueMessage({
    required P2PMessage message,
    required String senderId,
    required MessagePriority priorityType,
  }) {
    if (_messageQueue.length >= _maxQueueSize) {
      logger.warn('Fila de despacho cheia. Mensagem descartada: ${message.messageId}', tag: 'Dispatcher');
      return false;
    }

    // 1. Obter o STT Score do remetente (usado como prioridade secundária)
    final sttScore = _reputationCore.getReputationScore(senderId)?.score ?? 0.5;
    
    final queuedMessage = _QueuedMessage(
      message: message,
      priorityType: priorityType,
      sttScore: sttScore,
      senderId: senderId,
      timestamp: DateTime.now(),
    );

    _messageQueue.add(queuedMessage);
    logger.debug('Mensagem enfileirada. QoS: $priorityType, Score: ${sttScore.toStringAsFixed(2)}', tag: 'Dispatcher');
    return true;
  }

  /// Inicia o processo de despacho de mensagens.
  void _startDispatching() {
    // Despacha a cada 100ms
    _dispatchTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _processQueue();
    });
  }

  /// Processa a fila de mensagens, respeitando o limite de concorrência.
  void _processQueue() {
    while (_messageQueue.isNotEmpty && _concurrentSends < _maxConcurrentSends) {
      final queuedMessage = _messageQueue.removeFirst();
      _concurrentSends++;
      
      _dispatchMessage(queuedMessage);
    }
  }

  /// Envia a mensagem e gerencia o contador de concorrência.
  void _dispatchMessage(_QueuedMessage queuedMessage) {
    final serializedData = jsonEncode(queuedMessage.message.toMap());
    
    _p2pService.sendData(
      queuedMessage.message.receiverId, 
      serializedData, 
      priority: queuedMessage.priorityType,
      metadata: {'messageId': queuedMessage.message.messageId},
    )
      .then((success) {
        if (!success) {
          logger.warn('Falha no envio da mensagem ${queuedMessage.message.messageId}.', tag: 'Dispatcher');
          // NOTA: A lógica de re-enqueue com backoff é crucial em produção, mas omitida aqui por simplicidade.
        }
      })
      .catchError((e) {
        logger.error('Erro fatal ao despachar mensagem ${queuedMessage.message.messageId}: $e', tag: 'Dispatcher');
      })
      .whenComplete(() {
        _concurrentSends--;
        _processQueue(); // Garante o máximo de envios concorrentes
      });
  }

  /// Verifica se o limite de envio foi atingido (para o P2PService).
  bool isSendingLimitReached() {
    return _messageQueue.length >= _maxQueueSize || _concurrentSends >= _maxConcurrentSends;
  }

  /// Limpa recursos.
  void dispose() {
    _dispatchTimer?.cancel();
    _messageQueue.clear();
  }
}

/// Classe auxiliar para armazenar mensagens na fila.
class _QueuedMessage {
  final P2PMessage message;
  final MessagePriority priorityType; // Prioridade de QoS
  final double sttScore; // Prioridade de Reputação
  final String senderId;
  final DateTime timestamp; // Para desempate FIFO

  _QueuedMessage({
    required this.message,
    required this.priorityType,
    required this.sttScore,
    required this.senderId,
    required this.timestamp,
  });
}
