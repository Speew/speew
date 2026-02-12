import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/peer.dart';
import '../services/p2p_service.dart';
import '../services/storage_service.dart';
import '../services/mesh_routing_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final P2PService _p2pService;
  final StorageService _storageService;
  final MeshRoutingService _meshRoutingService; // Added for future use

  List<Peer> _peers = [];
  bool _isInitialized = false;
  StreamSubscription<List<Peer>>? _peerSubscription;

  List<Peer> get peers => _peers;
  bool get isInitialized => _isInitialized;

  ConnectionProvider({
    required P2PService p2pService,
    required StorageService storageService,
    required MeshRoutingService meshService, // Changed to meshService
  })
      : _p2pService = p2pService,
        _storageService = storageService,
        _meshRoutingService = meshService;

  Future<void> initialize(String userName) async {
    if (_isInitialized) return;

    await _p2pService.initialize(userName);

    _peers = await _storageService.getPeers();
    _isInitialized = true;
    notifyListeners();

    _peerSubscription = _p2pService.peerStream.listen((peers) {
      _updatePeers(peers);
    });

    await startDiscovery();
  }

  Future<void> startDiscovery() async {
    await _p2pService.startAdvertising();
    await _p2pService.startDiscovery();
  }

  void _updatePeers(List<Peer> newPeers) {
    for (final peer in newPeers) {
      final index = _peers.indexWhere((p) => p.id == peer.id);
      if (index != -1) {
        _peers[index] = peer;
      } else {
        _peers.add(peer);
      }

      _storageService.savePeer(peer);
    }

    _peers.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

    notifyListeners();
  }

  @override
  void dispose() {
    _peerSubscription?.cancel();
    _p2pService.stopAdvertising();
    _p2pService.stopDiscovery();
    super.dispose();
  }
}
