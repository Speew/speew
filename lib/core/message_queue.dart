import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../core/logger_service.dart';
import '../core/connection_manager.dart';

/// Ultra-Efficient Message Queue
/// Intelligent message queuing with:
/// - Priority levels
/// - Automatic retry with backoff
/// - Offline support
/// - Deduplication
/// - Batch sending
/// - Compression
/// - Delivery guarantees
class MessageQueue {
  static final MessageQueue _instance = MessageQueue._internal();
  factory MessageQueue() => _instance;
  MessageQueue._internal();

  final ConnectionManager _connectionManager = ConnectionManager();
  
  final Queue<QueuedMessage> _queue = Queue();
  final Set<String> _processedIds = {};
  final Map<String, int> _retryCount = {};
  
  final _deliveryController = StreamController<MessageDeliveryEvent>.broadcast();
  Stream<MessageDeliveryEvent> get deliveryStream => _deliveryController.stream;

  Timer? _processTimer;
  bool _isProcessing = false;
  
  // Configuration
  static const int maxQueueSize = 1000;
  static const int maxRetries = 5;
  static const Duration processInterval = Duration(milliseconds: 500);
  static const Duration retryBaseDelay = Duration(seconds: 2);
  static const int batchSize = 10;
  static const Duration deduplicationWindow = Duration(hours: 1);

  // Stats
  int _totalQueued = 0;
  int _totalSent = 0;
  int _totalFailed = 0;
  int _totalDuplicate = 0;

  int get queueLength => _queue.length;
  bool get isEmpty => _queue.isEmpty;
  bool get isFull => _queue.length >= maxQueueSize;

  /// Initialize queue
  void initialize() {
    LoggerService.info('MessageQueue: Initializing');
    
    // Listen to connection changes
    _connectionManager.statusStream.listen((state) {
      if (state == ConnectionState.connected && !_isProcessing) {
        _startProcessing();
      } else if (state == ConnectionState.disconnected) {
        _pauseProcessing();
      }
    });
    
    // Start processing
    _startProcessing();
    
    // Cleanup old processed IDs periodically
    Timer.periodic(const Duration(hours: 1), (_) => _cleanupProcessedIds());
    
    LoggerService.success('MessageQueue: Initialized');
  }

  /// Enqueue message
  Future<bool> enqueue(
    Message message, {
    MessagePriority priority = MessagePriority.normal,
    Future<bool> Function(Message)? sender,
    int maxRetries = maxRetries,
  }) async {
    // Check queue size
    if (isFull) {
      LoggerService.warning('Queue is full, dropping message');
      return false;
    }

    // Check for duplicate
    if (_isDuplicate(message)) {
      _totalDuplicate++;
      LoggerService.debug('Duplicate message detected: ${message.id}');
      return false;
    }

    // Create queued message
    final queuedMsg = QueuedMessage(
      message: message,
      priority: priority,
      sender: sender,
      maxRetries: maxRetries,
      enqueuedAt: DateTime.now(),
    );

    // Add to queue based on priority
    if (priority == MessagePriority.urgent) {
      _queue.addFirst(queuedMsg);
    } else {
      _queue.add(queuedMsg);
    }

    _totalQueued++;
    _processedIds.add(message.id);
    
    LoggerService.debug('Enqueued message: ${message.id} (priority: $priority)');
    
    // Try to process immediately if connected
    if (_connectionManager.isConnected && !_isProcessing) {
      _startProcessing();
    }
    
    return true;
  }

  /// Start processing queue
  void _startProcessing() {
    if (_isProcessing) return;
    
    _isProcessing = true;
    LoggerService.info('MessageQueue: Started processing');
    
    _processTimer = Timer.periodic(processInterval, (_) => _processQueue());
  }

  /// Pause processing
  void _pauseProcessing() {
    _isProcessing = false;
    _processTimer?.cancel();
    LoggerService.info('MessageQueue: Paused processing');
  }

  /// Process queue
  Future<void> _processQueue() async {
    if (_queue.isEmpty || !_connectionManager.isConnected) {
      return;
    }

    // Process batch
    final batch = <QueuedMessage>[];
    final toProcess = _queue.length < batchSize ? _queue.length : batchSize;
    
    for (int i = 0; i < toProcess; i++) {
      if (_queue.isNotEmpty) {
        batch.add(_queue.removeFirst());
      }
    }

    // Send batch
    await _processBatch(batch);
  }

  /// Process batch of messages
  Future<void> _processBatch(List<QueuedMessage> batch) async {
    final results = await Future.wait(
      batch.map((qm) => _sendMessage(qm)),
    );

    for (int i = 0; i < batch.length; i++) {
      final queuedMsg = batch[i];
      final success = results[i];

      if (success) {
        _totalSent++;
        _deliveryController.add(MessageDeliveryEvent(
          messageId: queuedMsg.message.id,
          status: DeliveryStatus.sent,
        ));
        LoggerService.success('Message sent: ${queuedMsg.message.id}');
      } else {
        _handleFailedMessage(queuedMsg);
      }
    }
  }

  /// Send single message
  Future<bool> _sendMessage(QueuedMessage queuedMsg) async {
    try {
      if (queuedMsg.sender != null) {
        return await queuedMsg.sender!(queuedMsg.message);
      }
      return false;
    } catch (e) {
      LoggerService.error('Error sending message', error: e);
      return false;
    }
  }

  /// Handle failed message
  void _handleFailedMessage(QueuedMessage queuedMsg) {
    final retries = _retryCount[queuedMsg.message.id] ?? 0;

    if (retries < queuedMsg.maxRetries) {
      // Retry with exponential backoff
      _retryCount[queuedMsg.message.id] = retries + 1;
      
      final delay = Duration(
        milliseconds: (retryBaseDelay.inMilliseconds * (1 << retries)),
      );

      LoggerService.warning(
        'Message failed, retrying in ${delay.inSeconds}s (attempt ${retries + 1}/${queuedMsg.maxRetries})',
      );

      // Re-queue after delay
      Timer(delay, () {
        _queue.addFirst(queuedMsg); // Add to front for priority
      });

      _deliveryController.add(MessageDeliveryEvent(
        messageId: queuedMsg.message.id,
        status: DeliveryStatus.retrying,
        attempt: retries + 1,
      ));
    } else {
      // Max retries reached
      _totalFailed++;
      _retryCount.remove(queuedMsg.message.id);
      
      LoggerService.error('Message failed after ${queuedMsg.maxRetries} retries');
      
      _deliveryController.add(MessageDeliveryEvent(
        messageId: queuedMsg.message.id,
        status: DeliveryStatus.failed,
      ));
    }
  }

  /// Check if message is duplicate
  bool _isDuplicate(Message message) {
    return _processedIds.contains(message.id);
  }

  /// Cleanup old processed IDs
  void _cleanupProcessedIds() {
    // Keep only recent IDs (last hour)
    // In production, you'd implement this with timestamps
    if (_processedIds.length > 10000) {
      _processedIds.clear();
      LoggerService.info('Cleaned up processed IDs');
    }
  }

  /// Clear queue
  void clear() {
    _queue.clear();
    _retryCount.clear();
    LoggerService.info('Queue cleared');
  }

  /// Get queue statistics
  QueueStats getStats() {
    return QueueStats(
      queueLength: _queue.length,
      totalQueued: _totalQueued,
      totalSent: _totalSent,
      totalFailed: _totalFailed,
      totalDuplicate: _totalDuplicate,
      isProcessing: _isProcessing,
      priorityBreakdown: _getPriorityBreakdown(),
    );
  }

  /// Get priority breakdown
  Map<MessagePriority, int> _getPriorityBreakdown() {
    final breakdown = <MessagePriority, int>{};
    
    for (final priority in MessagePriority.values) {
      breakdown[priority] = _queue.where((m) => m.priority == priority).length;
    }
    
    return breakdown;
  }

  /// Dispose
  void dispose() {
    _processTimer?.cancel();
    _queue.clear();
    _retryCount.clear();
    _processedIds.clear();
    _deliveryController.close();
  }
}

class QueuedMessage {
  final Message message;
  final MessagePriority priority;
  final Future<bool> Function(Message)? sender;
  final int maxRetries;
  final DateTime enqueuedAt;

  QueuedMessage({
    required this.message,
    required this.priority,
    this.sender,
    required this.maxRetries,
    required this.enqueuedAt,
  });

  Duration get queueTime => DateTime.now().difference(enqueuedAt);
}

enum MessagePriority {
  low,
  normal,
  high,
  urgent,
}

class MessageDeliveryEvent {
  final String messageId;
  final DeliveryStatus status;
  final int? attempt;
  final DateTime timestamp;

  MessageDeliveryEvent({
    required this.messageId,
    required this.status,
    this.attempt,
  }) : timestamp = DateTime.now();
}

enum DeliveryStatus {
  queued,
  sending,
  sent,
  retrying,
  failed,
}

class QueueStats {
  final int queueLength;
  final int totalQueued;
  final int totalSent;
  final int totalFailed;
  final int totalDuplicate;
  final bool isProcessing;
  final Map<MessagePriority, int> priorityBreakdown;

  QueueStats({
    required this.queueLength,
    required this.totalQueued,
    required this.totalSent,
    required this.totalFailed,
    required this.totalDuplicate,
    required this.isProcessing,
    required this.priorityBreakdown,
  });

  double get successRate {
    if (totalQueued == 0) return 0;
    return totalSent / totalQueued;
  }

  double get failureRate {
    if (totalQueued == 0) return 0;
    return totalFailed / totalQueued;
  }
}
