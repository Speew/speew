import 'dart:async';
import 'dart:convert';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/peer.dart';

class P2PService {
  final Nearby _nearby = Nearby();
  final StreamController<Peer> _discoveredPeersController =
      StreamController<Peer>.broadcast();
  final StreamController<Map<String, dynamic>> _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();

  final Map<String, Peer> _discoveredPeers = {};
  final List<String> _connectedPeers = [];
  
  String? _myDeviceId;
  bool _isAdvertising = false;
  bool _isDiscovering = false;

  // Getters
  Stream<Peer> get discoveredPeersStream => _discoveredPeersController.stream;
  Stream<Map<String, dynamic>> get messagesStream => _messagesController.stream;
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;
  
  List<Peer> get discoveredPeers => _discoveredPeers.values.toList();
  List<String> get connectedPeerIds => List.from(_connectedPeers);
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;

  // Iniciar como servidor (advertising)
  Future<bool> startAdvertising(String userName) async {
    try {
      final result = await _nearby.startAdvertising(
        userName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );

      _isAdvertising = result;
      _connectionStatusController.add('Advertising as: $userName');
      return result;
    } catch (e) {
      _connectionStatusController.add('Error advertising: $e');
      return false;
    }
  }

  // Iniciar descoberta de peers
  Future<bool> startDiscovery(String userName) async {
    try {
      final result = await _nearby.startDiscovery(
        userName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );

      _isDiscovering = result;
      _connectionStatusController.add('Discovering peers...');
      return result;
    } catch (e) {
      _connectionStatusController.add('Error discovering: $e');
      return false;
    }
  }

  // Parar advertising
  Future<void> stopAdvertising() async {
    await _nearby.stopAdvertising();
    _isAdvertising = false;
  }

  // Parar discovery
  Future<void> stopDiscovery() async {
    await _nearby.stopDiscovery();
    _isDiscovering = false;
  }

  // Conectar a um peer
  Future<void> connectToPeer(String endpointId, String userName) async {
    try {
      await _nearby.requestConnection(
        userName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      
      _connectionStatusController.add('Requesting connection to: $endpointId');
    } catch (e) {
      _connectionStatusController.add('Error connecting: $e');
    }
  }

  // Desconectar de um peer
  Future<void> disconnectFromPeer(String endpointId) async {
    try {
      await _nearby.disconnectFromEndpoint(endpointId);
      _connectedPeers.remove(endpointId);
      
      if (_discoveredPeers.containsKey(endpointId)) {
        _discoveredPeers[endpointId] = _discoveredPeers[endpointId]!
            .copyWith(isConnected: false);
      }
      
      _connectionStatusController.add('Disconnected from: $endpointId');
    } catch (e) {
      _connectionStatusController.add('Error disconnecting: $e');
    }
  }

  // Enviar mensagem
  Future<bool> sendMessage(String peerId, String message) async {
    try {
      final payload = jsonEncode({
        'type': 'message',
        'content': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await _nearby.sendBytesPayload(
        peerId,
        utf8.encode(payload),
      );

      return true;
    } catch (e) {
      _connectionStatusController.add('Error sending message: $e');
      return false;
    }
  }

  // Callbacks
  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    final peer = Peer(
      id: endpointId,
      name: endpointName,
      lastSeen: DateTime.now(),
      isConnected: false,
    );

    _discoveredPeers[endpointId] = peer;
    _discoveredPeersController.add(peer);
    _connectionStatusController.add('Found peer: $endpointName');
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId != null) {
      _discoveredPeers.remove(endpointId);
      _connectionStatusController.add('Lost peer: $endpointId');
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _connectionStatusController.add(
      'Connection initiated with: ${info.endpointName}',
    );
    
    // Auto-aceitar conexão
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedPeers.add(endpointId);
      
      if (_discoveredPeers.containsKey(endpointId)) {
        _discoveredPeers[endpointId] = _discoveredPeers[endpointId]!
            .copyWith(isConnected: true);
      }
      
      _connectionStatusController.add('Connected to: $endpointId');
    } else {
      _connectionStatusController.add('Connection failed: $endpointId');
    }
  }

  void _onDisconnected(String endpointId) {
    _connectedPeers.remove(endpointId);
    
    if (_discoveredPeers.containsKey(endpointId)) {
      _discoveredPeers[endpointId] = _discoveredPeers[endpointId]!
          .copyWith(isConnected: false);
    }
    
    _connectionStatusController.add('Disconnected from: $endpointId');
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      try {
        final data = utf8.decode(payload.bytes!);
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        
        if (decoded['type'] == 'message') {
          _messagesController.add({
            'sender_id': endpointId,
            'content': decoded['content'],
            'timestamp': decoded['timestamp'],
          });
        }
      } catch (e) {
        _connectionStatusController.add('Error receiving payload: $e');
      }
    }
  }

  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    // Callback para progresso de transferência (útil para arquivos grandes)
    if (update.status == PayloadStatus.SUCCESS) {
      _connectionStatusController.add('Payload transferred successfully');
    }
  }

  // Limpar recursos
  void dispose() {
    stopAdvertising();
    stopDiscovery();
    _discoveredPeersController.close();
    _messagesController.close();
    _connectionStatusController.close();
  }
}
