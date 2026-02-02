import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Performance Optimizer - Sistema central de otimizações
/// Aplica otimizações automáticas em todo o app
class PerformanceOptimizer {
  static final PerformanceOptimizer _instance = PerformanceOptimizer._internal();
  factory PerformanceOptimizer() => _instance;
  PerformanceOptimizer._internal();

  // Metrics
  final _performanceMetrics = <String, PerformanceMetric>{};
  
  // Optimizers
  final MessageBatcher messageBatcher = MessageBatcher();
  final ConnectionPool connectionPool = ConnectionPool();
  final MemoryCache memoryCache = MemoryCache();
  final LazyLoader lazyLoader = LazyLoader();
  
  Timer? _metricsTimer;

  /// Inicializar otimizador
  void initialize() {
    _startMetricsCollection();
    debugPrint('🚀 Performance Optimizer initialized');
  }

  /// Registrar métrica de performance
  void recordMetric(String operation, Duration duration) {
    _performanceMetrics[operation] ??= PerformanceMetric(operation);
    _performanceMetrics[operation]!.record(duration);
  }

  /// Obter relatório de performance
  Map<String, dynamic> getPerformanceReport() {
    return {
      'metrics': _performanceMetrics.map(
        (key, metric) => MapEntry(key, metric.toJson()),
      ),
      'message_batching': messageBatcher.getStats(),
      'connection_pool': connectionPool.getStats(),
      'memory_cache': memoryCache.getStats(),
    };
  }

  void _startMetricsCollection() {
    _metricsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _logPerformanceMetrics(),
    );
  }

  void _logPerformanceMetrics() {
    final report = getPerformanceReport();
    debugPrint('📊 Performance Report: $report');
  }

  void dispose() {
    _metricsTimer?.cancel();
    messageBatcher.dispose();
    connectionPool.dispose();
    memoryCache.dispose();
  }
}

/// Message Batcher - Agrupa mensagens para reduzir I/O
class MessageBatcher {
  final Queue<BatchItem> _queue = Queue();
  Timer? _flushTimer;
  
  static const int batchSize = 10;
  static const Duration batchInterval = Duration(milliseconds: 500);
  
  int _totalBatched = 0;
  int _totalSaved = 0;

  MessageBatcher() {
    _startBatchTimer();
  }

  /// Adicionar item ao batch
  void add(dynamic item, Future<void> Function(dynamic) processor) {
    _queue.add(BatchItem(item, processor));
    
    // Flush imediato se atingiu limite
    if (_queue.length >= batchSize) {
      _flush();
    }
  }

  /// Flush manual
  Future<void> flush() async {
    await _flush();
  }

  Future<void> _flush() async {
    if (_queue.isEmpty) return;

    final batch = <BatchItem>[];
    
    // Pegar até batchSize items
    while (_queue.isNotEmpty && batch.length < batchSize) {
      batch.add(_queue.removeFirst());
    }

    _totalBatched += batch.length;

    // Processar batch em paralelo
    await Future.wait(
      batch.map((item) => item.processor(item.data)),
    );

    _totalSaved += batch.length;
  }

  void _startBatchTimer() {
    _flushTimer = Timer.periodic(batchInterval, (_) => _flush());
  }

  Map<String, dynamic> getStats() {
    return {
      'queue_size': _queue.length,
      'total_batched': _totalBatched,
      'total_saved': _totalSaved,
      'efficiency': _totalBatched > 0 
          ? '${((_totalBatched - _totalSaved) / _totalBatched * 100).toStringAsFixed(1)}%'
          : '0%',
    };
  }

  void dispose() {
    _flushTimer?.cancel();
    _queue.clear();
  }
}

class BatchItem {
  final dynamic data;
  final Future<void> Function(dynamic) processor;

  BatchItem(this.data, this.processor);
}

/// Connection Pool - Reusa conexões para performance
class ConnectionPool {
  final Map<String, PooledConnection> _pool = {};
  
  static const int maxPoolSize = 20;
  static const Duration connectionTimeout = Duration(minutes: 5);
  
  Timer? _cleanupTimer;
  int _hits = 0;
  int _misses = 0;

  ConnectionPool() {
    _startCleanup();
  }

  /// Obter ou criar conexão
  Future<T> getConnection<T>(
    String key,
    Future<T> Function() factory,
  ) async {
    // Verificar pool
    if (_pool.containsKey(key)) {
      final conn = _pool[key]!;
      
      if (!conn.isExpired) {
        _hits++;
        conn.touch();
        return conn.connection as T;
      } else {
        _pool.remove(key);
      }
    }

    // Criar nova conexão
    _misses++;
    final connection = await factory();
    
    // Adicionar ao pool
    if (_pool.length < maxPoolSize) {
      _pool[key] = PooledConnection(connection, connectionTimeout);
    }

    return connection;
  }

  /// Remover conexão
  void release(String key) {
    _pool.remove(key);
  }

  /// Cleanup de conexões expiradas
  void _cleanup() {
    _pool.removeWhere((key, conn) => conn.isExpired);
  }

  void _startCleanup() {
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _cleanup(),
    );
  }

  Map<String, dynamic> getStats() {
    return {
      'pool_size': _pool.length,
      'hits': _hits,
      'misses': _misses,
      'hit_rate': '${(_hits / (_hits + _misses) * 100).toStringAsFixed(1)}%',
    };
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _pool.clear();
  }
}

class PooledConnection {
  final dynamic connection;
  final Duration timeout;
  DateTime lastAccessed;

  PooledConnection(this.connection, this.timeout)
      : lastAccessed = DateTime.now();

  bool get isExpired => DateTime.now().difference(lastAccessed) > timeout;

  void touch() {
    lastAccessed = DateTime.now();
  }
}

/// Memory Cache - Cache em memória com LRU
class MemoryCache {
  final LinkedHashMap<String, CacheEntry> _cache = LinkedHashMap();
  
  static const int maxSize = 100;
  static const Duration defaultTTL = Duration(minutes: 5);
  
  int _hits = 0;
  int _misses = 0;

  /// Obter do cache
  T? get<T>(String key) {
    final entry = _cache[key];
    
    if (entry == null) {
      _misses++;
      return null;
    }

    if (entry.isExpired) {
      _cache.remove(key);
      _misses++;
      return null;
    }

    _hits++;
    
    // Move para o fim (LRU)
    _cache.remove(key);
    _cache[key] = entry;
    
    return entry.value as T;
  }

  /// Adicionar ao cache
  void put<T>(String key, T value, {Duration? ttl}) {
    // Remove mais antigo se cheio
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = CacheEntry(value, ttl ?? defaultTTL);
  }

  /// Remover do cache
  void remove(String key) {
    _cache.remove(key);
  }

  /// Limpar cache
  void clear() {
    _cache.clear();
  }

  Map<String, dynamic> getStats() {
    return {
      'size': _cache.length,
      'hits': _hits,
      'misses': _misses,
      'hit_rate': '${(_hits / (_hits + _misses) * 100).toStringAsFixed(1)}%',
    };
  }

  void dispose() {
    _cache.clear();
  }
}

class CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  CacheEntry(this.value, Duration ttl)
      : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Lazy Loader - Carrega dados sob demanda
class LazyLoader {
  final Map<String, Future<dynamic>> _loading = {};
  
  int _totalLoads = 0;
  int _duplicatesPrevented = 0;

  /// Carregar com deduplicação
  Future<T> load<T>(
    String key,
    Future<T> Function() loader,
  ) async {
    // Se já está carregando, retorna a mesma Future
    if (_loading.containsKey(key)) {
      _duplicatesPrevented++;
      return await _loading[key] as T;
    }

    _totalLoads++;
    
    // Iniciar carregamento
    final future = loader();
    _loading[key] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _loading.remove(key);
    }
  }

  Map<String, dynamic> getStats() {
    return {
      'currently_loading': _loading.length,
      'total_loads': _totalLoads,
      'duplicates_prevented': _duplicatesPrevented,
      'efficiency': '${(_duplicatesPrevented / _totalLoads * 100).toStringAsFixed(1)}%',
    };
  }
}

/// Performance Metric - Rastreia métricas de uma operação
class PerformanceMetric {
  final String operation;
  final List<Duration> _samples = [];
  
  static const int maxSamples = 100;

  PerformanceMetric(this.operation);

  void record(Duration duration) {
    _samples.add(duration);
    
    // Manter apenas últimas N amostras
    if (_samples.length > maxSamples) {
      _samples.removeAt(0);
    }
  }

  Map<String, dynamic> toJson() {
    if (_samples.isEmpty) {
      return {
        'operation': operation,
        'count': 0,
      };
    }

    final sorted = List<Duration>.from(_samples)..sort();
    final total = _samples.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    
    return {
      'operation': operation,
      'count': _samples.length,
      'avg_ms': (total / _samples.length / 1000).toStringAsFixed(2),
      'min_ms': (sorted.first.inMicroseconds / 1000).toStringAsFixed(2),
      'max_ms': (sorted.last.inMicroseconds / 1000).toStringAsFixed(2),
      'p50_ms': (sorted[sorted.length ~/ 2].inMicroseconds / 1000).toStringAsFixed(2),
      'p95_ms': (sorted[(sorted.length * 0.95).floor()].inMicroseconds / 1000).toStringAsFixed(2),
    };
  }
}

/// Debouncer - Previne execuções excessivas
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Throttler - Limita taxa de execução
class Throttler {
  final Duration interval;
  DateTime? _lastRun;

  Throttler({this.interval = const Duration(milliseconds: 500)});

  void run(VoidCallback action) {
    final now = DateTime.now();
    
    if (_lastRun == null || now.difference(_lastRun!) > interval) {
      _lastRun = now;
      action();
    }
  }
}

/// Image Optimizer - Otimiza carregamento de imagens
class ImageOptimizer {
  static final _cache = <String, Uint8List>{};
  
  static const int maxCacheSize = 50 * 1024 * 1024; // 50MB
  static int _currentCacheSize = 0;

  /// Carregar imagem com cache
  static Future<Uint8List?> loadImage(
    String path,
    Future<Uint8List> Function() loader,
  ) async {
    // Verificar cache
    if (_cache.containsKey(path)) {
      return _cache[path];
    }

    // Carregar
    final data = await loader();
    
    // Adicionar ao cache se couber
    if (_currentCacheSize + data.length <= maxCacheSize) {
      _cache[path] = data;
      _currentCacheSize += data.length;
    } else {
      // Limpar cache mais antigo
      _evictOldest(data.length);
      _cache[path] = data;
      _currentCacheSize += data.length;
    }

    return data;
  }

  static void _evictOldest(int neededSpace) {
    int freed = 0;
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (freed >= neededSpace) break;
      
      freed += entry.value.length;
      keysToRemove.add(entry.key);
    }

    for (final key in keysToRemove) {
      final data = _cache.remove(key);
      if (data != null) {
        _currentCacheSize -= data.length;
      }
    }
  }

  static void clearCache() {
    _cache.clear();
    _currentCacheSize = 0;
  }
}
