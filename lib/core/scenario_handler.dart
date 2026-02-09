import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'error/error_handler.dart';
import 'utils.dart';

/// ScenarioHandler - Prepara o app para diferentes cenários
/// Gerencia edge cases, degradação graciosa, e modos de emergência
class ScenarioHandler {
  static final ScenarioHandler _instance = ScenarioHandler._internal();
  factory ScenarioHandler() => _instance;
  ScenarioHandler._internal();

  final _connectivity = Connectivity();
  final _battery = Battery();
  final _deviceInfo = DeviceInfoPlugin();

  // Estado do sistema
  DeviceScenario _currentScenario = DeviceScenario.normal;
  NetworkState _networkState = NetworkState.unknown;
  BatteryState _batteryState = BatteryState.unknown;
  int _batteryLevel = 100;
  bool _isLowMemory = false;
  bool _isDiskSpaceLow = false;

  // Listeners
  final _scenarioController = StreamController<DeviceScenario>.broadcast();
  Stream<DeviceScenario> get scenarioStream => _scenarioController.stream;

  // Limites adaptativos
  int _maxConcurrentConnections = 8;
  int _messageQueueLimit = 1000;
  int _fileSizeLimit = 100 * 1024 * 1024; // 100MB
  bool _enableHeavyFeatures = true;

  // Getters
  DeviceScenario get currentScenario => _currentScenario;
  bool get isLowPowerMode => _batteryLevel < 20;
  bool get isCriticalPowerMode => _batteryLevel < 10;
  bool get isNetworkConstrained => _networkState == NetworkState.mobile;
  bool get canUseHeavyFeatures => _enableHeavyFeatures && !isLowPowerMode;
  int get maxConnections => _maxConcurrentConnections;
  int get messageQueueLimit => _messageQueueLimit;
  int get fileSizeLimit => _fileSizeLimit;

  Future<void> initialize() async {
    try {
      await _checkDeviceCapabilities();
      await _monitorBattery();
      await _monitorNetwork();
      await _monitorResources();
      
      DebugUtils.log('ScenarioHandler initialized', tag: 'SCENARIO');
    } catch (e) {
      ErrorHandler.handleError(e);
    }
  }

  Future<void> _checkDeviceCapabilities() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        // Android antigo - limitar recursos
        if (sdkInt < 24) {
          _adjustForLowEndDevice();
          DebugUtils.log('Low-end Android detected (SDK $sdkInt)', tag: 'SCENARIO');
        }
        
        // RAM baixa
        final totalMemory = androidInfo.totalMemory ?? 0;
        if (totalMemory < 2 * 1024 * 1024 * 1024) { // < 2GB
          _adjustForLowMemory();
          DebugUtils.log('Low RAM device ($totalMemory bytes)', tag: 'SCENARIO');
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final model = iosInfo.model;
        
        // iOS antigo
        if (iosInfo.systemVersion.startsWith('12') || 
            iosInfo.systemVersion.startsWith('13')) {
          _adjustForLowEndDevice();
          DebugUtils.log('Older iOS detected', tag: 'SCENARIO');
        }
      }
    } catch (e) {
      DebugUtils.logError('Device capability check failed', error: e);
      // Assume low-end para segurança
      _adjustForLowEndDevice();
    }
  }

  Future<void> _monitorBattery() async {
    try {
      // Estado inicial
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
      _updatePowerMode();

      // Monitor contínuo
      _battery.onBatteryStateChanged.listen((state) {
        _batteryState = state;
        _updatePowerMode();
      });

      // Check periódico do nível
      Timer.periodic(const Duration(minutes: 1), (_) async {
        _batteryLevel = await _battery.batteryLevel;
        _updatePowerMode();
      });
    } catch (e) {
      DebugUtils.logError('Battery monitoring failed', error: e);
    }
  }

  void _updatePowerMode() {
    if (_batteryLevel < 10) {
      _enterCriticalPowerMode();
    } else if (_batteryLevel < 20) {
      _enterLowPowerMode();
    } else if (_batteryState == BatteryState.charging) {
      _exitPowerSavingMode();
    }
  }

  Future<void> _monitorNetwork() async {
    try {
      // Estado inicial
      final result = await _connectivity.checkConnectivity();
      _updateNetworkState(result.first);

      // Monitor contínuo
      _connectivity.onConnectivityChanged.listen((results) {
        if (results.isNotEmpty) {
          _updateNetworkState(results.first);
        }
      });
    } catch (e) {
      DebugUtils.logError('Network monitoring failed', error: e);
      _networkState = NetworkState.unknown;
    }
  }

  void _updateNetworkState(ConnectivityResult result) {
    final oldState = _networkState;
    
    switch (result) {
      case ConnectivityResult.wifi:
        _networkState = NetworkState.wifi;
        break;
      case ConnectivityResult.mobile:
        _networkState = NetworkState.mobile;
        break;
      case ConnectivityResult.ethernet:
        _networkState = NetworkState.ethernet;
        break;
      default:
        _networkState = NetworkState.none;
    }

    if (oldState != _networkState) {
      _adaptToNetwork();
      DebugUtils.log('Network changed: $_networkState', tag: 'SCENARIO');
    }
  }

  void _adaptToNetwork() {
    switch (_networkState) {
      case NetworkState.none:
        _enterOfflineMode();
        break;
      case NetworkState.mobile:
        _enterDataSavingMode();
        break;
      case NetworkState.wifi:
      case NetworkState.ethernet:
        _enableFullFeatures();
        break;
      case NetworkState.unknown:
        _enterConservativeMode();
        break;
    }
  }

  Future<void> _monitorResources() async {
    // Monitor de memória a cada 30s
    Timer.periodic(const Duration(seconds: 30), (_) {
      _checkMemoryPressure();
    });

    // Monitor de disco a cada 5 minutos
    Timer.periodic(const Duration(minutes: 5), (_) {
      _checkDiskSpace();
    });
  }

  void _checkMemoryPressure() {
    // Simples heurística baseada em comportamento do app
    // Em produção, usar platform channels para métricas reais
    try {
      // Se temos muitos objetos na memória, considere pressão
      // Este é um placeholder - implementação real seria mais sofisticada
      _isLowMemory = false; // Seria calculado dinamicamente
      
      if (_isLowMemory) {
        _handleMemoryPressure();
      }
    } catch (e) {
      DebugUtils.logError('Memory check failed', error: e);
    }
  }

  void _checkDiskSpace() {
    // Placeholder - em produção, verificar espaço real
    _isDiskSpaceLow = false;
    
    if (_isDiskSpaceLow) {
      _handleLowDiskSpace();
    }
  }

  // ==================== MODOS DE OPERAÇÃO ====================

  void _enterOfflineMode() {
    _currentScenario = DeviceScenario.offline;
    _maxConcurrentConnections = 0;
    _enableHeavyFeatures = false;
    _scenarioController.add(_currentScenario);
    
    DebugUtils.log('🔴 OFFLINE MODE', tag: 'SCENARIO');
  }

  void _enterLowPowerMode() {
    _currentScenario = DeviceScenario.lowPower;
    _maxConcurrentConnections = 3;
    _messageQueueLimit = 500;
    _fileSizeLimit = 50 * 1024 * 1024; // 50MB
    _enableHeavyFeatures = false;
    _scenarioController.add(_currentScenario);
    
    DebugUtils.log('🟡 LOW POWER MODE', tag: 'SCENARIO');
  }

  void _enterCriticalPowerMode() {
    _currentScenario = DeviceScenario.criticalPower;
    _maxConcurrentConnections = 1;
    _messageQueueLimit = 100;
    _fileSizeLimit = 10 * 1024 * 1024; // 10MB
    _enableHeavyFeatures = false;
    _scenarioController.add(_currentScenario);
    
    DebugUtils.log('🔴 CRITICAL POWER MODE', tag: 'SCENARIO');
  }

  void _enterDataSavingMode() {
    if (_currentScenario != DeviceScenario.lowPower && 
        _currentScenario != DeviceScenario.criticalPower) {
      _currentScenario = DeviceScenario.dataSaving;
      _maxConcurrentConnections = 5;
      _fileSizeLimit = 25 * 1024 * 1024; // 25MB
      _scenarioController.add(_currentScenario);
      
      DebugUtils.log('📱 DATA SAVING MODE', tag: 'SCENARIO');
    }
  }

  void _enterConservativeMode() {
    _currentScenario = DeviceScenario.conservative;
    _maxConcurrentConnections = 4;
    _messageQueueLimit = 750;
    _enableHeavyFeatures = false;
    _scenarioController.add(_currentScenario);
    
    DebugUtils.log('⚠️ CONSERVATIVE MODE', tag: 'SCENARIO');
  }

  void _exitPowerSavingMode() {
    if (_batteryLevel > 30 && _batteryState == BatteryState.charging) {
      _enableFullFeatures();
    }
  }

  void _enableFullFeatures() {
    if (_networkState != NetworkState.none && 
        !_isLowMemory && 
        !_isDiskSpaceLow) {
      _currentScenario = DeviceScenario.normal;
      _maxConcurrentConnections = 8;
      _messageQueueLimit = 1000;
      _fileSizeLimit = 100 * 1024 * 1024; // 100MB
      _enableHeavyFeatures = true;
      _scenarioController.add(_currentScenario);
      
      DebugUtils.log('✅ FULL FEATURES MODE', tag: 'SCENARIO');
    }
  }

  void _adjustForLowEndDevice() {
    _maxConcurrentConnections = 4;
    _messageQueueLimit = 500;
    _fileSizeLimit = 50 * 1024 * 1024;
    _enableHeavyFeatures = false;
  }

  void _adjustForLowMemory() {
    _isLowMemory = true;
    _messageQueueLimit = 300;
    _enableHeavyFeatures = false;
  }

  void _handleMemoryPressure() {
    DebugUtils.log('⚠️ Memory pressure detected', tag: 'SCENARIO');
    
    // Reduzir limites temporariamente
    _messageQueueLimit = (_messageQueueLimit * 0.7).round();
    _maxConcurrentConnections = (_maxConcurrentConnections * 0.7).round().clamp(1, 8);
    
    // Notificar app para limpar caches
    _scenarioController.add(DeviceScenario.memoryPressure);
  }

  void _handleLowDiskSpace() {
    DebugUtils.log('⚠️ Low disk space detected', tag: 'SCENARIO');
    
    // Reduzir limite de arquivos drasticamente
    _fileSizeLimit = 5 * 1024 * 1024; // 5MB
    
    _scenarioController.add(DeviceScenario.lowDiskSpace);
  }

  // ==================== DECISÕES ADAPTATIVAS ====================

  bool shouldAcceptConnection() {
    switch (_currentScenario) {
      case DeviceScenario.offline:
        return false;
      case DeviceScenario.criticalPower:
        return false; // Não aceitar novas conexões
      case DeviceScenario.lowPower:
        return true; // Mas limitado
      default:
        return true;
    }
  }

  bool shouldEnableFileTransfer() {
    switch (_currentScenario) {
      case DeviceScenario.offline:
      case DeviceScenario.criticalPower:
      case DeviceScenario.lowDiskSpace:
        return false;
      default:
        return true;
    }
  }

  bool shouldEnableVoiceCall() {
    switch (_currentScenario) {
      case DeviceScenario.offline:
      case DeviceScenario.criticalPower:
        return false;
      case DeviceScenario.dataSaving:
        return false; // Economizar dados móveis
      default:
        return true;
    }
  }

  bool shouldEnableVideoCall() {
    switch (_currentScenario) {
      case DeviceScenario.normal:
        return _networkState == NetworkState.wifi || 
               _networkState == NetworkState.ethernet;
      default:
        return false; // Video só em condições ideais
    }
  }

  bool shouldAutoDownloadMedia() {
    switch (_currentScenario) {
      case DeviceScenario.normal:
        return _networkState == NetworkState.wifi;
      default:
        return false;
    }
  }

  int getOptimalChunkSize() {
    switch (_networkState) {
      case NetworkState.wifi:
      case NetworkState.ethernet:
        return 64 * 1024; // 64KB
      case NetworkState.mobile:
        return 32 * 1024; // 32KB
      default:
        return 16 * 1024; // 16KB
    }
  }

  Duration getOptimalRetryDelay(int attemptNumber) {
    final baseDelay = switch (_networkState) {
      NetworkState.wifi || NetworkState.ethernet => 1,
      NetworkState.mobile => 2,
      _ => 5,
    };

    // Exponential backoff
    final delay = baseDelay * (1 << attemptNumber.clamp(0, 5));
    return Duration(seconds: delay);
  }

  // ==================== FALLBACKS ====================

  T withFallback<T>(T Function() primary, T fallback) {
    try {
      return primary();
    } catch (e) {
      DebugUtils.logError('Primary operation failed, using fallback', error: e);
      return fallback;
    }
  }

  Future<T> withAsyncFallback<T>(
    Future<T> Function() primary,
    T fallback, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      return await primary().timeout(timeout);
    } catch (e) {
      DebugUtils.logError('Primary async operation failed, using fallback', error: e);
      return fallback;
    }
  }

  // ==================== DIAGNOSTICS ====================

  Map<String, dynamic> getDiagnostics() {
    return {
      'scenario': _currentScenario.toString(),
      'network': _networkState.toString(),
      'battery_level': _batteryLevel,
      'battery_state': _batteryState.toString(),
      'is_low_power': isLowPowerMode,
      'is_critical_power': isCriticalPowerMode,
      'is_low_memory': _isLowMemory,
      'is_disk_low': _isDiskSpaceLow,
      'max_connections': _maxConcurrentConnections,
      'message_queue_limit': _messageQueueLimit,
      'file_size_limit': _fileSizeLimit,
      'heavy_features_enabled': _enableHeavyFeatures,
    };
  }

  void dispose() {
    _scenarioController.close();
  }
}

// ==================== ENUMS ====================

enum DeviceScenario {
  normal,
  lowPower,
  criticalPower,
  dataSaving,
  offline,
  conservative,
  memoryPressure,
  lowDiskSpace,
}

enum NetworkState {
  wifi,
  mobile,
  ethernet,
  none,
  unknown,
}

// ==================== EXTENSIONS ====================

extension ScenarioExtensions on DeviceScenario {
  bool get isRestricted => this != DeviceScenario.normal;
  
  String get displayName {
    switch (this) {
      case DeviceScenario.normal:
        return 'Normal';
      case DeviceScenario.lowPower:
        return 'Economia de Bateria';
      case DeviceScenario.criticalPower:
        return 'Bateria Crítica';
      case DeviceScenario.dataSaving:
        return 'Economia de Dados';
      case DeviceScenario.offline:
        return 'Offline';
      case DeviceScenario.conservative:
        return 'Modo Conservativo';
      case DeviceScenario.memoryPressure:
        return 'Pressão de Memória';
      case DeviceScenario.lowDiskSpace:
        return 'Espaço em Disco Baixo';
    }
  }
}
