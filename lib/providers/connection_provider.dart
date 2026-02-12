import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/peer.dart';
import '../services/p2p_service.dart';
import '../services/storage_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final P2PService _p2p = P2PService();
  final StorageService _storage = StorageService();

  List<Peer> _peers = [];
  bool _isInitialized = false;
  StreamSubscription<List<Peer>>? _peerSubscription;

  List<Peer> get peers => _peers;
  bool get isInitialized => _isInitialized;

  Future<void> initialize(String userName) async {
    await _p2p.initialize(userName);
    
    _peers = await _storage.getPeers();
    _isInitialized = true;
    notifyListeners();

    _peerSubscription = _p2p.peerStream.listen((peers) {
      _updatePeers(peers);
    });

    await startDiscovery();
  }

  Future<void> startDiscovery() async {
    await _p2p.startAdvertising();
    await _p2p.startDiscovery();
  }

  void _updatePeers(List<Peer> newPeers) {
    for (final peer in newPeers) {
      final index = _peers.indexWhere((p) => p.id == peer.id);
      if (index != -1) {
        _peers[index] = peer;
      } else {
        _peers.add(peer);
      }

      _storage.savePeer(peer);
    }

    _peers.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    
    notifyListeners();
  }

  @override
  void dispose() {
    _peerSubscription?.cancel();
    super.dispose();
  }
}
