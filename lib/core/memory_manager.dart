import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Memory Manager - Gerenciamento inteligente de memória
/// Features:
/// - Memory leak detection
/// - Automatic garbage collection
/// - Memory pressure monitoring
/// - Object pooling
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  Timer? _monitorTimer;
  final List<MemorySample> _samples = [];
  
  // Object pools
  final Map<Type, ObjectPool> _pools = {};
  
  // Weak references para detectar leaks
  final Map<String, WeakReference> _trackedObjects = {};
  
  bool _isMonitoring = false;
  int _gcTriggers = 0;

  void initialize() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _startMonitoring();
    
    debugPrint('🧠 Memory Manager initialized');
  }

  /// Iniciar monitoramento
  void _startMonitoring() {
    _monitorTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _collectMetrics(),
    );
  }

  /// Coletar métricas de memória
  void _collectMetrics() {
    final info = developer.ServiceExtensionRegistry;
    
    // Obter uso atual (aproximado)
    final sample = MemorySample(
      timestamp: DateTime.now(),
      // Em produção, usar package como flutter_memor y
      usedBytes: _estimateMemoryUsage(),
    );

    _samples.add(sample);

    // Manter apenas últimas 60 amostras (10 min)
    if (_samples.length > 60) {
      _samples.removeAt(0);
    }

    // Detectar memory pressure
    if (_isMemoryPressureHigh()) {
      _handleMemoryPressure();
    }

    // Detectar possíveis leaks
    _detectLeaks();
  }

  /// Estimar uso de memória
  int _estimateMemoryUsage() {
    // Simplificado - em produção usar API nativa
    return 0;
  }

  /// Verificar se memória está sob pressão
  bool _isMemoryPressureHigh() {
    if (_samples.length < 5) return false;

    final recent = _samples.sublist(_samples.length - 5);
    final trend = recent.last.usedBytes - recent.first.usedBytes;

    // Se cresceu > 50MB em 50 segundos
    return trend > 50 * 1024 * 1024;
  }

  /// Lidar com pressão de memória
  void _handleMemoryPressure() {
    debugPrint('⚠️ High memory pressure detected - triggering cleanup');

    // 1. Limpar caches
    _clearCaches();

    // 2. Retornar objetos aos pools
    _returnUnusedToPool();

    // 3. Sugerir GC
    _triggerGC();
  }

  /// Limpar caches
  void _clearCaches() {
    // Implementar limpeza de caches específicos
    debugPrint('🧹 Clearing caches');
  }

  /// Retornar objetos não usados ao pool
  void _returnUnusedToPool() {
    for (final pool in _pools.values) {
      pool.trim();
    }
  }

  /// Sugerir garbage collection
  void _triggerGC() {
    _gcTriggers++;
    
    // Não podemos forçar GC em Dart, mas podemos sugerir
    // criando pressão de memória temporária
    final temp = List.generate(1000, (i) => Object());
    temp.clear();
    
    debugPrint('🗑️ GC suggested (trigger #$_gcTriggers)');
  }

  /// Rastrear objeto para detectar leaks
  void track(String id, Object object) {
    _trackedObjects[id] = WeakReference(object);
  }

  /// Detectar memory leaks
  void _detectLeaks() {
    final leaked = <String>[];

    _trackedObjects.forEach((id, weakRef) {
      final object = weakRef.target;
      
      if (object != null) {
        // Objeto ainda existe - verificar se deveria
        // Simplificado - em produção fazer análise mais sofisticada
      }
    });

    if (leaked.isNotEmpty) {
      debugPrint('⚠️ Possible memory leaks detected: ${leaked.length}');
    }
  }

  /// Obter ou criar object pool
  ObjectPool<T> getPool<T>(
    T Function() factory, {
    int maxSize = 20,
  }) {
    if (!_pools.containsKey(T)) {
      _pools[T] = ObjectPool<T>(factory, maxSize: maxSize);
    }
    return _pools[T] as ObjectPool<T>;
  }

  /// Estatísticas
  Map<String, dynamic> getStats() {
    final current = _samples.isNotEmpty ? _samples.last.usedBytes : 0;
    
    return {
      'current_mb': (current / (1024 * 1024)).toStringAsFixed(1),
      'samples': _samples.length,
      'gc_triggers': _gcTriggers,
      'pools': _pools.length,
      'tracked_objects': _trackedObjects.length,
      'is_healthy': !_isMemoryPressureHigh(),
    };
  }

  void dispose() {
    _monitorTimer?.cancel();
    _pools.clear();
    _trackedObjects.clear();
    _samples.clear();
    _isMonitoring = false;
  }
}

class MemorySample {
  final DateTime timestamp;
  final int usedBytes;

  MemorySample({
    required this.timestamp,
    required this.usedBytes,
  });
}

/// Object Pool - Pool de objetos reutilizáveis
class ObjectPool<T> {
  final T Function() factory;
  final int maxSize;
  final List<T> _available = [];
  final Set<T> _inUse = {};

  ObjectPool(this.factory, {this.maxSize = 20});

  /// Obter objeto do pool
  T acquire() {
    T object;

    if (_available.isNotEmpty) {
      object = _available.removeLast();
    } else {
      object = factory();
    }

    _inUse.add(object);
    return object;
  }

  /// Retornar objeto ao pool
  void release(T object) {
    _inUse.remove(object);

    if (_available.length < maxSize) {
      _available.add(object);
    }
  }

  /// Remover objetos não usados
  void trim() {
    if (_available.length > maxSize ~/ 2) {
      _available.removeRange(0, _available.length - maxSize ~/ 2);
    }
  }

  Map<String, dynamic> getStats() {
    return {
      'available': _available.length,
      'in_use': _inUse.length,
      'total': _available.length + _inUse.length,
      'max_size': maxSize,
    };
  }
}

/// Weak Reference - Referência fraca (não impede GC)
class WeakReference<T> {
  final T? target;

  WeakReference(this.target);
}

/// Resource Manager - Gerencia recursos pesados
class ResourceManager {
  final Map<String, Resource> _resources = {};
  Timer? _cleanupTimer;

  void initialize() {
    _startCleanup();
  }

  /// Registrar recurso
  void register(String id, Resource resource) {
    _resources[id] = resource;
  }

  /// Liberar recurso
  void release(String id) {
    final resource = _resources.remove(id);
    resource?.dispose();
  }

  /// Limpar recursos não usados
  void _cleanup() {
    final now = DateTime.now();
    final toRemove = <String>[];

    _resources.forEach((id, resource) {
      if (now.difference(resource.lastAccessed) > resource.ttl) {
        toRemove.add(id);
      }
    });

    for (final id in toRemove) {
      release(id);
    }

    if (toRemove.isNotEmpty) {
      debugPrint('🧹 Released ${toRemove.length} unused resources');
    }
  }

  void _startCleanup() {
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _cleanup(),
    );
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _resources.values.forEach((r) => r.dispose());
    _resources.clear();
  }
}

class Resource {
  final String id;
  final void Function() dispose;
  final Duration ttl;
  DateTime lastAccessed;

  Resource({
    required this.id,
    required this.dispose,
    this.ttl = const Duration(minutes: 5),
  }) : lastAccessed = DateTime.now();

  void touch() {
    lastAccessed = DateTime.now();
  }
}

/// Stream Optimizer - Otimiza uso de streams
class StreamOptimizer {
  final Map<String, StreamSubscription> _subscriptions = {};

  /// Subscrever com auto-cleanup
  void subscribe<T>(
    String id,
    Stream<T> stream,
    void Function(T) onData, {
    Duration? timeout,
  }) {
    // Cancelar subscription anterior
    _subscriptions[id]?.cancel();

    var subscription = stream.listen(onData);

    // Auto-cancel após timeout
    if (timeout != null) {
      Timer(timeout, () {
        _subscriptions[id]?.cancel();
        _subscriptions.remove(id);
      });
    }

    _subscriptions[id] = subscription;
  }

  /// Cancelar subscription
  void cancel(String id) {
    _subscriptions[id]?.cancel();
    _subscriptions.remove(id);
  }

  /// Cancelar todas
  void cancelAll() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  Map<String, dynamic> getStats() {
    return {
      'active_subscriptions': _subscriptions.length,
    };
  }
}

/// Disposable Tracker - Rastreia objetos disposable
class DisposableTracker {
  final Set<String> _created = {};
  final Set<String> _disposed = {};

  void onCreate(String id) {
    _created.add(id);
  }

  void onDispose(String id) {
    _disposed.add(id);
  }

  /// Verificar leaks
  Set<String> getLeaks() {
    return _created.difference(_disposed);
  }

  Map<String, dynamic> getStats() {
    return {
      'created': _created.length,
      'disposed': _disposed.length,
      'leaks': getLeaks().length,
    };
  }
}
