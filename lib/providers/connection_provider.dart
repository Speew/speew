import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/peer.dart';
import '../services/p2p_service.dart';
import '../services/mesh_routing_service.dart';
import '../core/error/error_handler.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class ConnectionProvider with ChangeNotifier {
  final P2PService _p2pService;
  final MeshRoutingService _meshService;
  
  ConnectionStatus _status = ConnectionStatus.disconnected;
  List<Peer> _connectedPeers = [];
  List<Peer> _nearbyPeers = [];
  String? _error;
  int _meshRouteCount = 0;
  
  StreamSubscription? _connectionStatusSub;
  StreamSubscription? _peersSub;
  StreamSubscription? _meshRouteSub;
  
  ConnectionProvider({
    required P2PService p2pService,
    required MeshRoutingService meshService,
  })  : _p2pService = p2pService,
        _meshService = meshService {
    _init();
  }
  
  // Getters
  ConnectionStatus get status => _status;
  List<Peer> get connectedPeers => _connectedPeers;
  List<Peer> get nearbyPeers => _nearbyPeers;
  String? get error => _error;
  int get meshRouteCount => _meshRouteCount;
  bool get isConnected => _status == ConnectionStatus.connected;
  int get peerCount => _connectedPeers.length;
  
  void _init() {
    _connectionStatusSub = _p2pService.connectionStatusStream.listen(_handleConnectionStatus);
    _peersSub = _p2pService.peersStream.listen(_handlePeersUpdate);
    _meshRouteSub = _meshService.routeCountStream.listen(_handleMeshRouteUpdate);
  }
  
  Future<void> startAdvertising() async {
    try {
      _status = ConnectionStatus.connecting;
      _error = null;
      notifyListeners();
      
      final success = await _p2pService.startAdvertising();
      
      if (success) {
        _status = ConnectionStatus.connected;
      } else {
        _status = ConnectionStatus.error;
        _error = 'Failed to start advertising';
      }
      
      notifyListeners();
    } catch (e, stack) {
      _status = ConnectionStatus.error;
      _error = e.toString();
      ErrorHandler.handleError(e, stack);
      notifyListeners();
    }
  }
  
  Future<void> startDiscovery() async {
    try {
      _status = ConnectionStatus.connecting;
      _error = null;
      notifyListeners();
      
      final success = await _p2pService.startDiscovery();
      
      if (success) {
        _status = ConnectionStatus.connected;
      } else {
        _status = ConnectionStatus.error;
        _error = 'Failed to start discovery';
      }
      
      notifyListeners();
    } catch (e, stack) {
      _status = ConnectionStatus.error;
      _error = e.toString();
      ErrorHandler.handleError(e, stack);
      notifyListeners();
    }
  }
  
  Future<void> connectToPeer(Peer peer) async {
    try {
      final success = await _p2pService.connectToPeer(peer.id);
      
      if (success) {
        if (!_connectedPeers.any((p) => p.id == peer.id)) {
          _connectedPeers.add(peer);
          notifyListeners();
        }
      }
    } catch (e, stack) {
      ErrorHandler.handleError(e, stack);
    }
  }
  
  Future<void> disconnectFromPeer(String peerId) async {
    try {
      await _p2pService.disconnectFromPeer(peerId);
      _connectedPeers.removeWhere((p) => p.id == peerId);
      notifyListeners();
    } catch (e, stack) {
      ErrorHandler.handleError(e, stack);
    }
  }
  
  Future<void> stopAll() async {
    try {
      await _p2pService.stopAdvertising();
      await _p2pService.stopDiscovery();
      _status = ConnectionStatus.disconnected;
      _connectedPeers.clear();
      _nearbyPeers.clear();
      notifyListeners();
    } catch (e, stack) {
      ErrorHandler.handleError(e, stack);
    }
  }
  
  void _handleConnectionStatus(ConnectionStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }
  
  void _handlePeersUpdate(Map<String, dynamic> data) {
    final connected = data['connected'] as List<Peer>? ?? [];
    final nearby = data['nearby'] as List<Peer>? ?? [];
    
    _connectedPeers = connected;
    _nearbyPeers = nearby;
    
    notifyListeners();
  }
  
  void _handleMeshRouteUpdate(int count) {
    _meshRouteCount = count;
    notifyListeners();
  }
  
  Future<void> refreshConnections() async {
    try {
      await _p2pService.refreshPeers();
    } catch (e, stack) {
      ErrorHandler.handleError(e, stack);
    }
  }
  
  @override
  @override
  void dispose() {
    _connectionStatusSub?.cancel();
    _peersSub?.cancel();
    _meshRouteSub?.cancel();
    stopAll();
    super.dispose();
  }
}
