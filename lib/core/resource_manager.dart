import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Resource Manager - Gerenciamento inteligente de recursos
/// Otimiza uso de CPU, memória, bateria e disco
class ResourceManager {
  static final ResourceManager _instance = ResourceManager._internal();
  factory ResourceManager() => _instance;
  ResourceManager._internal();

  // Device info
  int _totalMemoryMB = 0;
  int _cpuCores = 0;
  bool _isLowEndDevice = false;

  // Current usage
  int _currentMemoryUsageMB = 0;
  int _batteryLevel = 100;
  bool _isCharging = false;

  // Optimization mode
  OptimizationMode _mode = OptimizationMode.balanced;

  Timer? _monitoringTimer;

  /// Inicializar
  Future<void> initialize() async {
    await _detectDeviceCapabilities();
    await _checkBatteryStatus();
    _determineOptimizationMode();
    _startMonitoring();
  }

  /// Detectar capacidades do device
  Future<void> _detectDeviceCapabilities() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      
      // Estimar memória total (não há API direta)
      // Devices low-end geralmente têm < 2GB
      // Mid-range: 2-4GB
      // High-end: 4GB+
      
      // Baseado no ano de release e modelo
      if (androidInfo.version.sdkInt < 26) {
        // Android < 8.0 = provavelmente low-end
        _totalMemoryMB = 1536; // 1.5GB
        _isLowEndDevice = true;
      } else {
        _totalMemoryMB = 3072; // 3GB (assumir mid-range)
        _isLowEndDevice = false;
      }

      // CPU cores
      _cpuCores = Platform.numberOfProcessors;

    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      
      // iPhone models
      if (iosInfo.model.contains('iPhone')) {
        // iPhones modernos têm boa memória
        _totalMemoryMB = 4096; // 4GB
        _isLowEndDevice = false;
      }

      _cpuCores = Platform.numberOfProcessors;
    }
  }

  /// Verificar status da bateria
  Future<void> _checkBatteryStatus() async {
    final battery = Battery();
    
    _batteryLevel = await battery.batteryLevel;
    _isCharging = await battery.batteryState == BatteryState.charging;

    // Listen for changes
    battery.onBatteryStateChanged.listen((state) {
      _isCharging = state == BatteryState.charging;
      _determineOptimizationMode();
    });
  }

  /// Determinar modo de otimização
  void _determineOptimizationMode() {
    if (_batteryLevel < 20 && !_isCharging) {
      // Bateria baixa: modo agressivo
      _mode = OptimizationMode.aggressive;
    } else if (_isLowEndDevice) {
      // Device low-end: sempre economizar recursos
      _mode = OptimizationMode.aggressive;
    } else if (_isCharging && _batteryLevel > 80) {
      // Carregando com bateria alta: modo performance
      _mode = OptimizationMode.performance;
    } else {
      // Normal: modo balanceado
      _mode = OptimizationMode.balanced;
    }
  }

  /// Monitorar recursos
  void _startMonitoring() {
    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        await _updateResourceUsage();
        _determineOptimizationMode();
      },
    );
  }

  /// Atualizar uso de recursos
  Future<void> _updateResourceUsage() async {
    // Estimar uso de memória
    // Em produção: usar package como flutter_memory_info
    _currentMemoryUsageMB = 150; // Placeholder

    // Atualizar bateria
    final battery = Battery();
    _batteryLevel = await battery.batteryLevel;
  }

  /// Obter configurações otimizadas
  ResourceConfig getOptimizedConfig() {
    switch (_mode) {
      case OptimizationMode.performance:
        return ResourceConfig(
          maxConcurrentTasks: _cpuCores * 2,
          cacheSize: min(200, _totalMemoryMB ~/ 4), // MB
          imageQuality: 100,
          enableBackgroundSync: true,
          compressionLevel: 0, // Sem compressão
          maxChunkSize: 512 * 1024, // 512KB
        );

      case OptimizationMode.balanced:
        return ResourceConfig(
          maxConcurrentTasks: _cpuCores,
          cacheSize: min(100, _totalMemoryMB ~/ 8), // MB
          imageQuality: 85,
          enableBackgroundSync: true,
          compressionLevel: 3, // Compressão média
          maxChunkSize: 256 * 1024, // 256KB
        );

      case OptimizationMode.aggressive:
        return ResourceConfig(
          maxConcurrentTasks: max(1, _cpuCores ~/ 2),
          cacheSize: min(50, _totalMemoryMB ~/ 16), // MB
          imageQuality: 70,
          enableBackgroundSync: false,
          compressionLevel: 6, // Compressão alta
          maxChunkSize: 128 * 1024, // 128KB
        );
    }
  }

  /// Verificar se pode executar tarefa pesada
  bool canExecuteHeavyTask() {
    // Não executar se:
    // - Bateria baixa e não carregando
    // - Memória quase cheia
    // - Modo agressivo

    if (_batteryLevel < 15 && !_isCharging) return false;
    if (_currentMemoryUsageMB > _totalMemoryMB * 0.85) return false;
    if (_mode == OptimizationMode.aggressive) return false;

    return true;
  }

  /// Solicitar garbage collection
  void requestGC() {
    // Força garbage collection
    // Em Dart: não há controle direto, mas podemos limpar caches
    _clearUnusedCaches();
  }

  void _clearUnusedCaches() {
    // Implementar limpeza de caches não essenciais
  }

  /// Obter estatísticas
  Map<String, dynamic> getStats() {
    return {
      'total_memory_mb': _totalMemoryMB,
      'current_memory_mb': _currentMemoryUsageMB,
      'memory_usage_percent': '${(_currentMemoryUsageMB / _totalMemoryMB * 100).toStringAsFixed(1)}%',
      'cpu_cores': _cpuCores,
      'battery_level': '$_batteryLevel%',
      'is_charging': _isCharging,
      'is_low_end': _isLowEndDevice,
      'optimization_mode': _mode.toString().split('.').last,
    };
  }

  void dispose() {
    _monitoringTimer?.cancel();
  }
}

class ResourceConfig {
  final int maxConcurrentTasks;
  final int cacheSize; // MB
  final int imageQuality; // 0-100
  final bool enableBackgroundSync;
  final int compressionLevel; // 0-9
  final int maxChunkSize; // bytes

  ResourceConfig({
    required this.maxConcurrentTasks,
    required this.cacheSize,
    required this.imageQuality,
    required this.enableBackgroundSync,
    required this.compressionLevel,
    required this.maxChunkSize,
  });
}

enum OptimizationMode { performance, balanced, aggressive }

/// Memory Pool - Pool de objetos reutilizáveis
class MemoryPool<T> {
  final List<T> _available = [];
  final T Function() _factory;
  final void Function(T)? _reset;
  final int maxSize;

  int _created = 0;
  int _reused = 0;

  MemoryPool({
    required T Function() factory,
    void Function(T)? reset,
    this.maxSize = 100,
  })  : _factory = factory,
        _reset = reset;

  /// Obter objeto do pool
  T acquire() {
    if (_available.isNotEmpty) {
      _reused++;
      final obj = _available.removeLast();
      return obj;
    }

    _created++;
    return _factory();
  }

  /// Retornar objeto ao pool
  void release(T obj) {
    if (_available.length < maxSize) {
      _reset?.call(obj);
      _available.add(obj);
    }
  }

  /// Estatísticas
  Map<String, dynamic> getStats() {
    return {
      'available': _available.length,
      'created': _created,
      'reused': _reused,
      'reuse_rate': _created > 0
          ? '${(_reused / (_created + _reused) * 100).toStringAsFixed(1)}%'
          : '0%',
    };
  }

  void clear() {
    _available.clear();
  }
}

/// Task Scheduler - Agendamento inteligente de tarefas
class TaskScheduler {
  final _queue = <ScheduledTask>[];
  final ResourceManager _resourceManager = ResourceManager();

  Timer? _executionTimer;

  /// Agendar tarefa
  Future<T> schedule<T>({
    required Future<T> Function() task,
    TaskPriority priority = TaskPriority.normal,
    bool requiresHeavyResources = false,
  }) async {
    final completer = Completer<T>();

    _queue.add(ScheduledTask(
      task: () async {
        try {
          final result = await task();
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      },
      priority: priority,
      requiresHeavyResources: requiresHeavyResources,
    ));

    _scheduleExecution();

    return completer.future;
  }

  /// Executar tarefas agendadas
  void _scheduleExecution() {
    if (_executionTimer?.isActive ?? false) return;

    _executionTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _executeTasks(),
    );
  }

  void _executeTasks() {
    if (_queue.isEmpty) {
      _executionTimer?.cancel();
      return;
    }

    // Ordenar por prioridade
    _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    final task = _queue.first;

    // Verificar se pode executar
    if (task.requiresHeavyResources && 
        !_resourceManager.canExecuteHeavyTask()) {
      // Esperar melhores condições
      return;
    }

    _queue.removeAt(0);
    task.task();
  }

  int get queueSize => _queue.length;

  void dispose() {
    _executionTimer?.cancel();
    _queue.clear();
  }
}

class ScheduledTask {
  final Future<void> Function() task;
  final TaskPriority priority;
  final bool requiresHeavyResources;

  ScheduledTask({
    required this.task,
    required this.priority,
    required this.requiresHeavyResources,
  });
}

enum TaskPriority { low, normal, high, critical }

/// CPU Throttler - Controla uso de CPU
class CPUThrottler {
  final int maxCPUUsagePercent;
  DateTime _lastYield = DateTime.now();

  CPUThrottler({this.maxCPUUsagePercent = 80});

  /// Yield CPU se necessário
  Future<void> yieldIfNeeded() async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastYield);

    // Yield a cada 50ms para não monopolizar CPU
    if (elapsed.inMilliseconds > 50) {
      await Future.delayed(Duration.zero);
      _lastYield = DateTime.now();
    }
  }
}

int max(int a, int b) => a > b ? a : b;
int min(int a, int b) => a < b ? a : b;
