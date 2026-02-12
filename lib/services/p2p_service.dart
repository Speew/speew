import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/message.dart';
import '../models/peer.dart';

class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  final Nearby _nearby = Nearby();
  final Strategy _strategy = Strategy.P2P_CLUSTER;

  final _messageController = StreamController<Message>.broadcast();
  final _peerController = StreamController<List<Peer>>.broadcast();

  Stream<Message> get messageStream => _messageController.stream;
  Stream<List<Peer>> get peerStream => _peerController.stream;

  final Map<String, Peer> _connectedPeers = {};
  String _myId = '';
  String _myName = '';

  Future<void> initialize(String name) async {
    _myId = DateTime.now().millisecondsSinceEpoch.toString();
    _myName = name;

    await _nearby.askLocationAndExternalStoragePermission();
  }

  Future<void> startAdvertising() async {
    try {
      await _nearby.startAdvertising(
        _myName,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      debugPrint('Error starting advertising: $e');
    }
  }

  Future<void> startDiscovery() async {
    try {
      await _nearby.startDiscovery(
        _myName,
        _strategy,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );
    } catch (e) {
      debugPrint('Error starting discovery: $e');
    }
  }

  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    debugPrint('Found endpoint: $endpointName');
    
    _nearby.requestConnection(
      _myName,
      endpointId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
  }

  void _onEndpointLost(String? endpointId) {
    debugPrint('Lost endpoint: $endpointId');
    if (endpointId != null) {
      _connectedPeers.remove(endpointId);
      _updatePeers();
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    debugPrint('Connection initiated with: ${info.endpointName}');
    
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      debugPrint('Connected to: $endpointId');
      
      _connectedPeers[endpointId] = Peer(
        id: endpointId,
        name: 'Peer',
        lastSeen: DateTime.now(),
        isConnected: true,
      );
      
      _updatePeers();
    }
  }

  void _onDisconnected(String endpointId) {
    debugPrint('Disconnected from: $endpointId');
    _connectedPeers.remove(endpointId);
    _updatePeers();
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      try {
        final data = json.decode(utf8.decode(payload.bytes!));
        final message = Message.fromMap(data);
        _messageController.add(message);
      } catch (e) {
        debugPrint('Error decoding message: $e');
      }
    }
  }

  Future<void> sendMessage(Message message, String peerId) async {
    try {
      final data = json.encode(message.toMap());
      final bytes = utf8.encode(data);

      await _nearby.sendBytesPayload(peerId, bytes);
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  void _updatePeers() {
    _peerController.add(_connectedPeers.values.toList());
  }

  List<Peer> get connectedPeers => _connectedPeers.values.toList();

  Future<void> dispose() async {
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _nearby.stopAllEndpoints();
    
    await _messageController.close();
    await _peerController.close();
  }
}
