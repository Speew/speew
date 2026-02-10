import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/peer.dart';
import 'crypto_service.dart';
import 'storage_service.dart';

class P2PService {
  final CryptoService _cryptoService;
  final StorageService _storageService;

  P2PService({
    required CryptoService cryptoService,
    required StorageService storageService,
  })  : _cryptoService = cryptoService,
        _storageService = storageService;

  final Nearby _nearby = Nearby();
  final Strategy _strategy = Strategy.P2P_CLUSTER;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStatusController = StreamController<ConnectionStatus>.broadcast();
  final _peersController = StreamController<Map<String, dynamic>>.broadcast();

  final Map<String, Peer> _connectedPeers = {};
  final Map<String, Peer> _nearbyPeers = {};
  final Map<String, Timer> _heartbeats = {};
  final Map<String, int> _retryCount = {};

  String _currentUserId = '';
  String _userName = '';
  bool _isAdvertising = false;
  bool _isDiscovering = false;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<ConnectionStatus> get connectionStatusStream => _connectionStatusController.stream;
  Stream<Map<String, dynamic>> get peersStream => _peersController.stream;

  String get currentUserId => _currentUserId;
  List<Peer> get connectedPeers => _connectedPeers.values.toList();
  List<Peer> get nearbyPeers => _nearbyPeers.values.toList();

  Future<void> initialize(String userId, String userName) async {
    _currentUserId = userId;
    _userName = userName;
    await _nearby.askLocationAndExternalStoragePermission();
    await _cryptoService.initialize();
  }

  Future<bool> startAdvertising() async {
    if (_userName.isEmpty) return false;

    try {
      _isAdvertising = await _nearby.startAdvertising(
        _userName,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );

      if (_isAdvertising) {
        _connectionStatusController.add(ConnectionStatus.connected);
      }

      return _isAdvertising;
    } catch (e) {
      _connectionStatusController.add(ConnectionStatus.error);
      return false;
    }
  }

  Future<bool> startDiscovery() async {
    if (_userName.isEmpty) return false;

    try {
      _isDiscovering = await _nearby.startDiscovery(
        _userName,
        _strategy,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );

      if (_isDiscovering) {
        _connectionStatusController.add(ConnectionStatus.connected);
      }

      return _isDiscovering;
    } catch (e) {
      _connectionStatusController.add(ConnectionStatus.error);
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    await _nearby.stopAdvertising();
    _isAdvertising = false;
  }

  Future<void> stopDiscovery() async {
    await _nearby.stopDiscovery();
    _isDiscovering = false;
  }

  Future<bool> connectToPeer(String peerId) async {
    final peer = _nearbyPeers[peerId];
    if (peer == null) return false;

    try {
      final result = await _nearby.requestConnection(
        _userName,
        peerId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );

      return result;
    } catch (e) {
      _retryConnection(peerId);
      return false;
    }
  }

  Future<bool> acceptConnection(String peerId) async {
    try {
      final result = await _nearby.acceptConnection(
        peerId,
        onPayLoadRecieved: _onPayloadReceived,
      );

      if (result) {
        await _exchangeKeys(peerId);
        _startHeartbeat(peerId);
      }

      return result;
    } catch (e) {
      return false;
    }
  }

  Future<bool> rejectConnection(String peerId) async {
    try {
      return await _nearby.rejectConnection(peerId);
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendMessage({
    required String peerId,
    required String message,
    bool isGroup = false,
  }) async {
    try {
      final encrypted = await _cryptoService.encryptMessage(message, peerId);
      await _nearby.sendBytesPayload(peerId, Uint8List.fromList(encrypted.codeUnits));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendFile({
    required String peerId,
    required String filePath,
  }) async {
    try {
      await _nearby.sendFilePayload(peerId, filePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  void sendTypingIndicator(String peerId, bool isTyping) {
    final data = {'type': 'typing', 'isTyping': isTyping};
    _nearby.sendBytesPayload(peerId, Uint8List.fromList(data.toString().codeUnits));
  }

  Future<void> disconnectFromPeer(String peerId) async {
    await _nearby.disconnectFromEndpoint(peerId);
    _heartbeats[peerId]?.cancel();
    _heartbeats.remove(peerId);
    _connectedPeers.remove(peerId);
    _retryCount.remove(peerId);
    _updatePeersList();
  }

  Future<void> refreshPeers() async {
    for (final peer in _connectedPeers.values) {
      if (peer.isConnected) {
        final lastSeen = peer.lastSeen?.millisecondsSinceEpoch ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastSeen > 60000) {
          peer.isConnected = false;
          await _storageService.updatePeerStatus(peer.id, false);
        }
      }
    }
    _updatePeersList();
  }

  void _onEndpointFound(String endpointId, String name, String serviceId) {
    final peer = Peer(
      id: endpointId,
      name: name,
      isConnected: false,
      lastSeen: DateTime.now(),
    );

    _nearbyPeers[endpointId] = peer;
    _updatePeersList();
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId != null) {
      _nearbyPeers.remove(endpointId);
      _updatePeersList();
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    // Auto-accept connections for now
    acceptConnection(endpointId);
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      final peer = _nearbyPeers[endpointId] ?? Peer(id: endpointId, name: 'Unknown');
      peer.isConnected = true;
      peer.lastSeen = DateTime.now();

      _connectedPeers[endpointId] = peer;
      _nearbyPeers.remove(endpointId);
      _storageService.savePeer(peer);
      _storageService.updatePeerStatus(endpointId, true);

      _startHeartbeat(endpointId);
      _retryCount.remove(endpointId);
      _updatePeersList();
    }
  }

  void _onDisconnected(String endpointId) {
    final peer = _connectedPeers[endpointId];
    if (peer != null) {
      peer.isConnected = false;
      _storageService.updatePeerStatus(endpointId, false);
    }

    _heartbeats[endpointId]?.cancel();
    _heartbeats.remove(endpointId);
    _connectedPeers.remove(endpointId);

    _retryConnection(endpointId);
    _updatePeersList();
  }

  Future<void> _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final content = String.fromCharCodes(payload.bytes!);

      try {
        final decrypted = await _cryptoService.decryptMessage(content, endpointId);

        _messageController.add({
          'senderId': endpointId,
          'content': decrypted,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'type': 'text',
        });

        final peer = _connectedPeers[endpointId];
        if (peer != null) {
          peer.lastSeen = DateTime.now();
        }
      } catch (e) {
        // Handle typing indicator or other non-encrypted messages
        if (content.contains('typing')) {
          _typingController.add({
            'peerId': endpointId,
            'isTyping': content.contains('true'),
          });
        }
      }
    } else if (payload.type == PayloadType.FILE) {
      // Handle file received
    }
  }

  Future<void> _exchangeKeys(String peerId) async {
    try {
      final publicKey = await _cryptoService.getPublicKey();
      // Send public key to peer and receive their public key
      // Derive shared secret
    } catch (e) {
      // Error handling
    }
  }

  void _startHeartbeat(String peerId) {
    _heartbeats[peerId]?.cancel();
    _heartbeats[peerId] = Timer.periodic(const Duration(seconds: 30), (timer) {
      final peer = _connectedPeers[peerId];
      if (peer != null && peer.isConnected) {
        sendMessage(peerId: peerId, message: '__heartbeat__');
      } else {
        timer.cancel();
      }
    });
  }

  void _retryConnection(String peerId) {
    final count = _retryCount[peerId] ?? 0;
    if (count < 3) {
      _retryCount[peerId] = count + 1;
      Future.delayed(Duration(seconds: count * 2), () {
        connectToPeer(peerId);
      });
    }
  }

  void _updatePeersList() {
    _peersController.add({
      'connected': _connectedPeers.values.toList(),
      'nearby': _nearbyPeers.values.toList(),
    });
  }

  void dispose() {
    stopAdvertising();
    stopDiscovery();
    for (final timer in _heartbeats.values) {
      timer.cancel();
    }
    _messageController.close();
    _typingController.close();
    _connectionStatusController.close();
    _peersController.close();
  }
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}