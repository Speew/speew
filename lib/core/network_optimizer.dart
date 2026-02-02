import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Network Optimizer - Otimiza tráfego de rede
/// Features:
/// - Request deduplication (elimina duplicatas)
/// - Smart retry com exponential backoff
/// - Request prioritization
/// - Bandwidth management
/// - Connection health monitoring
class NetworkOptimizer {
  // Request deduplication
  final Map<String, Future<dynamic>> _inflightRequests = {};
  
  // Retry queue
  final Queue<RetryableRequest> _retryQueue = Queue();
  Timer? _retryTimer;
  
  // Priority queue
  final PriorityQueue<NetworkRequest> _priorityQueue = PriorityQueue();
  
  // Bandwidth tracking
  int _bytesSent = 0;
  int _bytesReceived = 0;
  DateTime _bandwidthResetTime = DateTime.now();
  
  // Connection health
  int _consecutiveFailures = 0;
  bool _isHealthy = true;
  
  // Statistics
  int _totalRequests = 0;
  int _deduplicatedRequests = 0;
  int _retriedRequests = 0;
  int _failedRequests = 0;

  /// Executar request com deduplicação
  Future<T> execute<T>(
    String requestId,
    Future<T> Function() request, {
    RequestPriority priority = RequestPriority.normal,
    bool enableRetry = true,
    int maxRetries = 3,
  }) async {
    _totalRequests++;

    // Verificar se já está em execução (deduplication)
    if (_inflightRequests.containsKey(requestId)) {
      _deduplicatedRequests++;
      debugPrint('🔄 Request deduplicated: $requestId');
      return await _inflightRequests[requestId] as T;
    }

    // Criar future e adicionar ao inflight
    final future = _executeWithRetry<T>(
      requestId,
      request,
      priority: priority,
      enableRetry: enableRetry,
      maxRetries: maxRetries,
    );

    _inflightRequests[requestId] = future;

    try {
      final result = await future;
      _consecutiveFailures = 0;
      _isHealthy = true;
      return result;
    } catch (e) {
      _consecutiveFailures++;
      _failedRequests++;
      
      if (_consecutiveFailures >= 3) {
        _isHealthy = false;
        debugPrint('⚠️ Network unhealthy: $e');
      }
      
      rethrow;
    } finally {
      _inflightRequests.remove(requestId);
    }
  }

  /// Executar com retry automático
  Future<T> _executeWithRetry<T>(
    String requestId,
    Future<T> Function() request, {
    required RequestPriority priority,
    required bool enableRetry,
    required int maxRetries,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        final result = await request();
        
        if (attempt > 0) {
          _retriedRequests++;
          debugPrint('✅ Request succeeded after $attempt retries: $requestId');
        }
        
        return result;
      } catch (e) {
        attempt++;

        if (!enableRetry || attempt >= maxRetries) {
          debugPrint('❌ Request failed after $attempt attempts: $requestId');
          rethrow;
        }

        // Exponential backoff
        final delay = _calculateBackoff(attempt);
        debugPrint('🔄 Retry $attempt/$maxRetries in ${delay.inMilliseconds}ms: $requestId');
        
        await Future.delayed(delay);
      }
    }
  }

  /// Calcular delay de backoff exponencial
  Duration _calculateBackoff(int attempt) {
    // 100ms, 200ms, 400ms, 800ms, 1600ms, ...
    final baseDelay = 100;
    final maxDelay = 5000;
    
    final delay = baseDelay * (1 << (attempt - 1));
    return Duration(milliseconds: delay.clamp(baseDelay, maxDelay));
  }

  /// Enfileirar request com prioridade
  void enqueue(NetworkRequest request) {
    _priorityQueue.add(request);
    _processQueue();
  }

  /// Processar fila de prioridade
  Future<void> _processQueue() async {
    while (_priorityQueue.isNotEmpty) {
      final request = _priorityQueue.removeFirst();
      
      try {
        await execute(
          request.id,
          request.executor,
          priority: request.priority,
        );
      } catch (e) {
        debugPrint('Queue request failed: ${request.id}');
      }
    }
  }

  /// Registrar bytes enviados
  void recordBytesSent(int bytes) {
    _bytesSent += bytes;
    _resetBandwidthIfNeeded();
  }

  /// Registrar bytes recebidos
  void recordBytesReceived(int bytes) {
    _bytesReceived += bytes;
    _resetBandwidthIfNeeded();
  }

  /// Obter bandwidth atual
  double getCurrentBandwidth() {
    final elapsed = DateTime.now().difference(_bandwidthResetTime);
    if (elapsed.inSeconds == 0) return 0.0;
    
    final totalBytes = _bytesSent + _bytesReceived;
    return totalBytes / elapsed.inSeconds; // bytes/sec
  }

  /// Verificar se deve throttle
  bool shouldThrottle({int maxBytesPerSecond = 1024 * 1024}) {
    return getCurrentBandwidth() > maxBytesPerSecond;
  }

  /// Reset de bandwidth tracking
  void _resetBandwidthIfNeeded() {
    final elapsed = DateTime.now().difference(_bandwidthResetTime);
    
    if (elapsed.inMinutes >= 1) {
      _bytesSent = 0;
      _bytesReceived = 0;
      _bandwidthResetTime = DateTime.now();
    }
  }

  /// Obter estatísticas
  Map<String, dynamic> getStats() {
    return {
      'total_requests': _totalRequests,
      'deduplicated': _deduplicatedRequests,
      'dedup_rate': _totalRequests > 0
          ? '${(_deduplicatedRequests / _totalRequests * 100).toStringAsFixed(1)}%'
          : '0%',
      'retried': _retriedRequests,
      'failed': _failedRequests,
      'success_rate': _totalRequests > 0
          ? '${((_totalRequests - _failedRequests) / _totalRequests * 100).toStringAsFixed(1)}%'
          : '100%',
      'inflight': _inflightRequests.length,
      'queue_size': _priorityQueue.length,
      'bandwidth_bps': getCurrentBandwidth().toStringAsFixed(0),
      'is_healthy': _isHealthy,
      'consecutive_failures': _consecutiveFailures,
    };
  }

  void dispose() {
    _retryTimer?.cancel();
    _inflightRequests.clear();
    _retryQueue.clear();
    _priorityQueue.clear();
  }
}

/// Request com retry
class RetryableRequest {
  final String id;
  final Future<dynamic> Function() executor;
  final int maxRetries;
  int attempts;

  RetryableRequest({
    required this.id,
    required this.executor,
    this.maxRetries = 3,
    this.attempts = 0,
  });
}

/// Network request com prioridade
class NetworkRequest implements Comparable<NetworkRequest> {
  final String id;
  final Future<dynamic> Function() executor;
  final RequestPriority priority;
  final DateTime createdAt;

  NetworkRequest({
    required this.id,
    required this.executor,
    required this.priority,
  }) : createdAt = DateTime.now();

  @override
  int compareTo(NetworkRequest other) {
    // Maior prioridade primeiro
    final priorityCompare = other.priority.index.compareTo(priority.index);
    
    if (priorityCompare != 0) return priorityCompare;
    
    // Se mesma prioridade, mais antigo primeiro
    return createdAt.compareTo(other.createdAt);
  }
}

enum RequestPriority {
  low,
  normal,
  high,
  urgent,
}

/// Priority Queue implementation
class PriorityQueue<T extends Comparable<T>> {
  final List<T> _heap = [];

  void add(T item) {
    _heap.add(item);
    _bubbleUp(_heap.length - 1);
  }

  T removeFirst() {
    if (_heap.isEmpty) throw StateError('Queue is empty');

    final first = _heap[0];
    final last = _heap.removeLast();

    if (_heap.isNotEmpty) {
      _heap[0] = last;
      _bubbleDown(0);
    }

    return first;
  }

  bool get isNotEmpty => _heap.isNotEmpty;
  bool get isEmpty => _heap.isEmpty;
  int get length => _heap.length;

  void clear() => _heap.clear();

  void _bubbleUp(int index) {
    while (index > 0) {
      final parentIndex = (index - 1) ~/ 2;
      
      if (_heap[index].compareTo(_heap[parentIndex]) >= 0) break;
      
      _swap(index, parentIndex);
      index = parentIndex;
    }
  }

  void _bubbleDown(int index) {
    while (true) {
      final leftChild = 2 * index + 1;
      final rightChild = 2 * index + 2;
      int smallest = index;

      if (leftChild < _heap.length &&
          _heap[leftChild].compareTo(_heap[smallest]) < 0) {
        smallest = leftChild;
      }

      if (rightChild < _heap.length &&
          _heap[rightChild].compareTo(_heap[smallest]) < 0) {
        smallest = rightChild;
      }

      if (smallest == index) break;

      _swap(index, smallest);
      index = smallest;
    }
  }

  void _swap(int i, int j) {
    final temp = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = temp;
  }
}

/// Circuit Breaker - Previne sobrecarga em falhas
class CircuitBreaker {
  final int failureThreshold;
  final Duration timeout;
  
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  CircuitState _state = CircuitState.closed;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 30),
  });

  Future<T> execute<T>(Future<T> Function() action) async {
    if (_state == CircuitState.open) {
      // Verificar se deve tentar novamente
      if (_shouldAttemptReset()) {
        _state = CircuitState.halfOpen;
      } else {
        throw CircuitBreakerOpenException();
      }
    }

    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    _failureCount = 0;
    _state = CircuitState.closed;
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
      debugPrint('⚠️ Circuit breaker opened after $failureThreshold failures');
    }
  }

  bool _shouldAttemptReset() {
    if (_lastFailureTime == null) return false;
    
    return DateTime.now().difference(_lastFailureTime!) > timeout;
  }

  Map<String, dynamic> getStats() {
    return {
      'state': _state.toString(),
      'failure_count': _failureCount,
      'last_failure': _lastFailureTime?.toIso8601String(),
    };
  }
}

enum CircuitState { closed, open, halfOpen }

class CircuitBreakerOpenException implements Exception {
  @override
  String toString() => 'Circuit breaker is open';
}
