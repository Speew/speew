import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/logger_service.dart';

/// Ultra-Optimized Connection Manager
/// Manages all network connections with intelligence and resilience
class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  final Connectivity _connectivity = Connectivity();

  final _statusController = StreamController<ConnectionState>.broadcast();
  final _qualityController = StreamController<ConnectionQuality>.broadcast();

  Stream<ConnectionState> get statusStream => _statusController.stream;
  Stream<ConnectionQuality> get qualityStream => _qualityController.stream;

  ConnectionState _currentState = ConnectionState.disconnected;
  ConnectionQuality _currentQuality = ConnectionQuality.unknown;
  ConnectivityResult _lastResult = ConnectivityResult.none;

  Timer? _healthCheckTimer;
  Timer? _reconnectTimer;
  Timer? _qualityCheckTimer;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _baseReconnectDelay = Duration(seconds: 2);

  DateTime? _lastConnectedAt;
  DateTime? _lastDisconnectedAt;
  int _bytesTransferred = 0;
  DateTime _bandwidthCheckStart = DateTime.now();

  bool autoReconnect = true;
  bool enableHealthChecks = true;
  Duration healthCheckInterval = const Duration(seconds: 30);

  ConnectionState get currentState => _currentState;
  ConnectionQuality get currentQuality => _currentQuality;
  bool get isConnected => _currentState == ConnectionState.connected;

  Future<void> initialize() async {
    LoggerService.info('ConnectionManager: Initializing');

    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    final results = await _connectivity.checkConnectivity();
    _onConnectivityChanged(results);

    if (enableHealthChecks) {
      _startHealthChecks();
    }

    _startQualityMonitoring();

    LoggerService.success('ConnectionManager: Initialized');
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    ConnectivityResult newResult;
    if (results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none)) {
      newResult = ConnectivityResult.none;
    } else {
      if (results.contains(ConnectivityResult.ethernet)) {
        newResult = ConnectivityResult.ethernet;
      } else if (results.contains(ConnectivityResult.wifi)) {
        newResult = ConnectivityResult.wifi;
      } else if (results.contains(ConnectivityResult.mobile)) {
        newResult = ConnectivityResult.mobile;
      } else {
        newResult = results.first;
      }
    }

    if (newResult == ConnectivityResult.none) {
      _lastResult = newResult;
      _handleDisconnected();
    } else {
      _lastResult = newResult;
      _handleConnected(newResult);
    }
  }

  void _handleConnected(ConnectivityResult result) {
    LoggerService.network('Connected via ${_getConnectionType(result)}');

    _lastConnectedAt = DateTime.now();
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();

    _updateState(ConnectionState.connected);
    _estimateQuality(result);

    _statusController.add(_currentState);
  }

  void _handleDisconnected() {
    LoggerService.warning('Connection lost');

    _lastDisconnectedAt = DateTime.now();
    _updateState(ConnectionState.disconnected);
    _updateQuality(ConnectionQuality.none);

    _statusController.add(_currentState);
    _qualityController.add(_currentQuality);

    if (autoReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;

    final delay = Duration(
      milliseconds: (_baseReconnectDelay.inMilliseconds * (1 << (_reconnectAttempts - 1).clamp(0, 5))),
    );

    LoggerService.info('Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _updateState(ConnectionState.reconnecting);
    _statusController.add(_currentState);

    _reconnectTimer = Timer(delay, () async {
      final results = await _connectivity.checkConnectivity();
      _onConnectivityChanged(results);
    });
  }

  void _startHealthChecks() {
    _healthCheckTimer = Timer.periodic(healthCheckInterval, (_) async {
      await _performHealthCheck();
    });
  }

  Future<void> _performHealthCheck() async {
    if (!isConnected) return;

    final results = await _connectivity.checkConnectivity();

    if ((results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none)) && isConnected) {
      LoggerService.warning('Health check failed - connection lost');
      _handleDisconnected();
    }
  }

  void _startQualityMonitoring() {
    _qualityCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _estimateQuality(_lastResult);
    });
  }

  void _estimateQuality(ConnectivityResult result) {
    ConnectionQuality quality;

    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        quality = ConnectionQuality.excellent;
        break;
      case ConnectivityResult.mobile:
        quality = ConnectionQuality.good;
        break;
      case ConnectivityResult.bluetooth:
        quality = ConnectionQuality.fair;
        break;
      default:
        quality = ConnectionQuality.none;
    }

    if (quality != _currentQuality) {
      _updateQuality(quality);
      _qualityController.add(quality);
    }
  }

  void _updateState(ConnectionState state) {
    _currentState = state;
    LoggerService.debug('Connection state: $state');
  }

  void _updateQuality(ConnectionQuality quality) {
    _currentQuality = quality;
    LoggerService.debug('Connection quality: $quality');
  }

  void trackDataTransfer(int bytes) {
    _bytesTransferred += bytes;
  }

  double getEstimatedBandwidth() {
    final elapsed = DateTime.now().difference(_bandwidthCheckStart);
    if (elapsed.inSeconds == 0) return 0;

    return _bytesTransferred / elapsed.inSeconds / 1024;
  }

  void resetBandwidthTracking() {
    _bytesTransferred = 0;
    _bandwidthCheckStart = DateTime.now();
  }

  String _getConnectionType(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      default:
        return 'Unknown';
    }
  }

  ConnectionInfo getInfo() {
    return ConnectionInfo(
      state: _currentState,
      quality: _currentQuality,
      type: _getConnectionType(_lastResult),
      isConnected: isConnected,
      lastConnectedAt: _lastConnectedAt,
      lastDisconnectedAt: _lastDisconnectedAt,
      reconnectAttempts: _reconnectAttempts,
      estimatedBandwidth: getEstimatedBandwidth(),
    );
  }

  Future<void> forceReconnect() async {
    LoggerService.info('Force reconnecting...');
    _reconnectAttempts = 0;
    _handleDisconnected();
  }

  void dispose() {
    _healthCheckTimer?.cancel();
    _reconnectTimer?.cancel();
    _qualityCheckTimer?.cancel();
    _statusController.close();
    _qualityController.close();
  }
}

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

enum ConnectionQuality {
  none,
  poor,
  fair,
  good,
  excellent,
  unknown,
}

class ConnectionInfo {
  final ConnectionState state;
  final ConnectionQuality quality;
  final String type;
  final bool isConnected;
  final DateTime? lastConnectedAt;
  final DateTime? lastDisconnectedAt;
  final int reconnectAttempts;
  final double estimatedBandwidth;

  ConnectionInfo({
    required this.state,
    required this.quality,
    required this.type,
    required this.isConnected,
    this.lastConnectedAt,
    this.lastDisconnectedAt,
    required this.reconnectAttempts,
    required this.estimatedBandwidth,
  });

  Duration? get uptime {
    if (!isConnected || lastConnectedAt == null) return null;
    return DateTime.now().difference(lastConnectedAt!);
  }

  Duration? get downtime {
    if (isConnected || lastDisconnectedAt == null) return null;
    return DateTime.now().difference(lastDisconnectedAt!);
  }
}
