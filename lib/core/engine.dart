import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Core Engine - Sistema central de otimização
/// Gerencia recursos, cache e performance do app
class CoreEngine {
  static final CoreEngine _instance = CoreEngine._internal();
  factory CoreEngine() => _instance;
  CoreEngine._internal();

  // Resource pools
  final Map<String, ObjectPool> _pools = {};
  
  // Global cache
  final LRUCache _cache = LRUCache(maxSize: 100);
  
  // Task queue
  final PriorityTaskQueue _taskQueue = PriorityTaskQueue();
  
  // Metrics
  final PerformanceMetrics _metrics = PerformanceMetrics();
  
  Timer? _metricsTimer;
  bool _isInitialized = false;

  /// Inicializar engine
  void initialize() {
    if (_isInitialized) return;
    
    _startMetricsMonitoring();
    _taskQueue.start();
    
    _isInitialized = true;
    debugPrint('🚀 Core Engine initialized');
  }

  /// Get object pool
  ObjectPool<T> getPool<T>(T Function() factory, {int maxSize = 20}) {
    final key = T.toString();
    
    if (!_pools.containsKey(key)) {
      _pools[key] = ObjectPool<T>(factory, maxSize: maxSize);
    }
    
    return _pools[key] as ObjectPool<T>;
  }

  /// Cache operations
  void cacheSet(String key, dynamic value, {Duration? ttl}) {
    _cache.put(key, value, ttl: ttl);
  }

  dynamic cacheGet(String key) {
    return _cache.get(key);
  }

  void cacheRemove(String key) {
    _cache.remove(key);
  }

  void cacheClear() {
    _cache.clear();
  }

  /// Task queue operations
  Future<T> runTask<T>({
    required Future<T> Function() task,
    TaskPriority priority = TaskPriority.normal,
  }) {
    return _taskQueue.add(task, priority: priority);
  }

  /// Metrics
  void recordMetric(String operation, Duration duration) {
    _metrics.record(operation, duration);
  }

  Map<String, dynamic> getMetrics() {
    return {
      'cache': _cache.getStats(),
      'pools': _pools.map((k, v) => MapEntry(k, v.getStats())),
      'tasks': _taskQueue.getStats(),
      'performance': _metrics.getStats(),
    };
  }

  void _startMetricsMonitoring() {
    _metricsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _logMetrics(),
    );
  }

  void _logMetrics() {
    if (kDebugMode) {
      final metrics = getMetrics();
      debugPrint('📊 Core Metrics: $metrics');
    }
  }

  void dispose() {
    _metricsTimer?.cancel();
    _taskQueue.stop();
    _pools.clear();
    _cache.clear();
    _isInitialized = false;
  }
}

/// Object Pool - Reusa objetos para evitar alocações
class ObjectPool<T> {
  final T Function() _factory;
  final int maxSize;
  final Queue<T> _available = Queue();
  final Set<T> _inUse = {};

  ObjectPool(this._factory, {this.maxSize = 20});

  T acquire() {
    T object;
    
    if (_available.isNotEmpty) {
      object = _available.removeFirst();
    } else {
      object = _factory();
    }
    
    _inUse.add(object);
    return object;
  }

  void release(T object) {
    _inUse.remove(object);
    
    if (_available.length < maxSize) {
      _available.add(object);
    }
  }

  Map<String, int> getStats() {
    return {
      'available': _available.length,
      'in_use': _inUse.length,
      'total': _available.length + _inUse.length,
    };
  }
}

/// LRU Cache - Cache com eviction automática
class LRUCache {
  final int maxSize;
  final LinkedHashMap<String, CacheEntry> _cache = LinkedHashMap();

  LRUCache({required this.maxSize});

  void put(String key, dynamic value, {Duration? ttl}) {
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }
    
    _cache[key] = CacheEntry(
      value: value,
      expiresAt: ttl != null ? DateTime.now().add(ttl) : null,
    );
  }

  dynamic get(String key) {
    final entry = _cache[key];
    
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    
    // Move to end (LRU)
    _cache.remove(key);
    _cache[key] = entry;
    
    return entry.value;
  }

  void remove(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }

  Map<String, int> getStats() {
    return {
      'size': _cache.length,
      'max_size': maxSize,
    };
  }
}

class CacheEntry {
  final dynamic value;
  final DateTime? expiresAt;

  CacheEntry({required this.value, this.expiresAt});

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

/// Priority Task Queue - Fila com prioridades
class PriorityTaskQueue {
  final PriorityQueue<Task> _queue = PriorityQueue();
  bool _isRunning = false;
  int _completed = 0;

  void start() {
    _isRunning = true;
    _processQueue();
  }

  void stop() {
    _isRunning = false;
  }

  Future<T> add<T>(Future<T> Function() task, {TaskPriority priority = TaskPriority.normal}) {
    final completer = Completer<T>();
    
    _queue.add(Task(
      execute: () async {
        try {
          final result = await task();
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      },
      priority: priority,
    ));
    
    return completer.future;
  }

  Future<void> _processQueue() async {
    while (_isRunning) {
      if (_queue.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }
      
      final task = _queue.removeFirst();
      await task.execute();
      _completed++;
    }
  }

  Map<String, int> getStats() {
    return {
      'queued': _queue.length,
      'completed': _completed,
    };
  }
}

class Task implements Comparable<Task> {
  final Future<void> Function() execute;
  final TaskPriority priority;

  Task({required this.execute, required this.priority});

  @override
  int compareTo(Task other) {
    return other.priority.index.compareTo(priority.index);
  }
}

enum TaskPriority { low, normal, high, urgent }

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

  bool get isEmpty => _heap.isEmpty;
  int get length => _heap.length;

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

      if (leftChild < _heap.length && _heap[leftChild].compareTo(_heap[smallest]) < 0) {
        smallest = leftChild;
      }
      if (rightChild < _heap.length && _heap[rightChild].compareTo(_heap[smallest]) < 0) {
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

/// Performance Metrics
class PerformanceMetrics {
  final Map<String, List<Duration>> _samples = {};

  void record(String operation, Duration duration) {
    _samples[operation] ??= [];
    _samples[operation]!.add(duration);
    
    // Keep only last 100 samples
    if (_samples[operation]!.length > 100) {
      _samples[operation]!.removeAt(0);
    }
  }

  Map<String, dynamic> getStats() {
    final stats = <String, dynamic>{};
    
    _samples.forEach((op, samples) {
      if (samples.isEmpty) return;
      
      final total = samples.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
      final avg = total / samples.length / 1000; // ms
      
      stats[op] = {
        'avg_ms': avg.toStringAsFixed(2),
        'count': samples.length,
      };
    });
    
    return stats;
  }
}
