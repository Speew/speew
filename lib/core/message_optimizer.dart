import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/message.dart';

/// Message Optimizer - Otimiza envio/recebimento de mensagens
/// Features:
/// - Compressão de mensagens
/// - Deduplicação
/// - Batching
/// - Retry automático
class MessageOptimizer {
  static final MessageOptimizer _instance = MessageOptimizer._internal();
  factory MessageOptimizer() => _instance;
  MessageOptimizer._internal();

  // Batch queue
  final List<Message> _pendingBatch = [];
  Timer? _batchTimer;
  
  // Message deduplication
  final Set<String> _sentHashes = {};
  
  // Retry queue
  final Map<String, RetryInfo> _retryQueue = {};
  Timer? _retryTimer;

  static const int batchSize = 10;
  static const Duration batchInterval = Duration(milliseconds: 500);
  static const int maxRetries = 3;

  /// Adicionar mensagem ao batch
  void addToBatch(Message message, Future<bool> Function(Message) sender) {
    // Check deduplication
    final hash = _hashMessage(message);
    if (_sentHashes.contains(hash)) {
      debugPrint('⚠️ Duplicate message detected, skipping');
      return;
    }

    _pendingBatch.add(message);
    _sentHashes.add(hash);

    // Start batch timer if not started
    _batchTimer ??= Timer(batchInterval, () => _processBatch(sender));

    // Process immediately if batch full
    if (_pendingBatch.length >= batchSize) {
      _batchTimer?.cancel();
      _processBatch(sender);
    }
  }

  /// Processar batch de mensagens
  Future<void> _processBatch(Future<bool> Function(Message) sender) async {
    if (_pendingBatch.isEmpty) return;

    final batch = List<Message>.from(_pendingBatch);
    _pendingBatch.clear();
    _batchTimer = null;

    debugPrint('📦 Processing batch of ${batch.length} messages');

    // Send all in parallel
    final results = await Future.wait(
      batch.map((msg) => sender(msg).catchError((_) => false)),
    );

    // Add failed messages to retry queue
    for (int i = 0; i < batch.length; i++) {
      if (!results[i]) {
        _addToRetryQueue(batch[i], sender);
      }
    }
  }

  /// Adicionar à fila de retry
  void _addToRetryQueue(Message message, Future<bool> Function(Message) sender) {
    _retryQueue[message.id] = RetryInfo(
      message: message,
      sender: sender,
      attempts: 0,
    );

    _retryTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => _processRetries(),
    );

    debugPrint('🔄 Message added to retry queue: ${message.id}');
  }

  /// Processar retries
  Future<void> _processRetries() async {
    if (_retryQueue.isEmpty) {
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }

    final toRemove = <String>[];

    for (final entry in _retryQueue.entries) {
      final info = entry.value;
      info.attempts++;

      if (info.attempts > maxRetries) {
        toRemove.add(entry.key);
        debugPrint('❌ Message failed after $maxRetries retries: ${entry.key}');
        continue;
      }

      final success = await info.sender(info.message).catchError((_) => false);

      if (success) {
        toRemove.add(entry.key);
        debugPrint('✅ Message sent after ${info.attempts} retries: ${entry.key}');
      }
    }

    for (final id in toRemove) {
      _retryQueue.remove(id);
    }
  }

  /// Comprimir conteúdo
  String compress(String content) {
    if (content.length < 100) return content;

    // Simple compression: remove extra spaces
    return content
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Descomprimir conteúdo
  String decompress(String content) {
    return content; // Placeholder
  }

  /// Hash de mensagem para deduplicação
  String _hashMessage(Message message) {
    final data = '${message.senderId}${message.receiverId}${message.content}${message.timestamp.millisecondsSinceEpoch ~/ 1000}';
    return md5.convert(utf8.encode(data)).toString().substring(0, 16);
  }

  /// Limpar hashes antigos (> 1h)
  void cleanupHashes() {
    _sentHashes.clear();
    debugPrint('🧹 Message hashes cleared');
  }

  /// Estatísticas
  Map<String, dynamic> getStats() {
    return {
      'pending_batch': _pendingBatch.length,
      'retry_queue': _retryQueue.length,
      'dedup_cache': _sentHashes.length,
    };
  }

  void dispose() {
    _batchTimer?.cancel();
    _retryTimer?.cancel();
    _pendingBatch.clear();
    _retryQueue.clear();
    _sentHashes.clear();
  }
}

class RetryInfo {
  final Message message;
  final Future<bool> Function(Message) sender;
  int attempts;

  RetryInfo({
    required this.message,
    required this.sender,
    this.attempts = 0,
  });
}
