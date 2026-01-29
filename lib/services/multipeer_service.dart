import 'dart:async';
import 'package:flutter/services.dart';
import '../models/peer.dart';
import '../core/utils.dart';

/// Serviço iOS usando Multipeer Connectivity
/// Equivalente ao Nearby Connections do Android
class MultipeerService {
  static const MethodChannel _channel = MethodChannel('speew/multipeer');
  static const EventChannel _discoveryChannel = EventChannel('speew/multipeer/discovery');
  static const EventChannel _messagesChannel = EventChannel('speew/multipeer/messages');

  final StreamController<Peer> _discoveredPeersController =
      StreamController<Peer>.broadcast();
  final StreamController<Map<String, dynamic>> _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();

  bool _initialized = false;
  String? _displayName;

  // Getters
  Stream<Peer> get discoveredPeersStream => _discoveredPeersController.stream;
  Stream<Map<String, dynamic>> get messagesStream => _messagesController.stream;
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;

  /// Inicializar serviço Multipeer
  Future<void> initialize(String displayName) async {
    if (_initialized) return;

    try {
      _displayName = displayName;
      
      await _channel.invokeMethod('initialize', {
        'displayName': displayName,
        'serviceType': 'speew-p2p', // Máx 15 caracteres
      });

      _setupEventChannels();
      _initialized = true;

      DebugUtils.log('Multipeer initialized', tag: 'MULTIPEER');
    } catch (e) {
      DebugUtils.logError('Failed to initialize Multipeer', error: e);
      rethrow;
    }
  }

  /// Configurar event channels
  void _setupEventChannels() {
    // Discovery events
    _discoveryChannel.receiveBroadcastStream().listen(
      (event) {
        final data = event as Map<dynamic, dynamic>;
        _handleDiscoveryEvent(data);
      },
      onError: (error) {
        DebugUtils.logError('Discovery channel error', error: error);
      },
    );

    // Message events
    _messagesChannel.receiveBroadcastStream().listen(
      (event) {
        final data = event as Map<dynamic, dynamic>;
        _handleMessageEvent(data);
      },
      onError: (error) {
        DebugUtils.logError('Messages channel error', error: error);
      },
    );
  }

  /// Iniciar advertising (servidor)
  Future<bool> startAdvertising() async {
    try {
      final result = await _channel.invokeMethod('startAdvertising');
      DebugUtils.log('Advertising started', tag: 'MULTIPEER');
      return result as bool;
    } catch (e) {
      DebugUtils.logError('Failed to start advertising', error: e);
      return false;
    }
  }

  /// Parar advertising
  Future<void> stopAdvertising() async {
    try {
      await _channel.invokeMethod('stopAdvertising');
      DebugUtils.log('Advertising stopped', tag: 'MULTIPEER');
    } catch (e) {
      DebugUtils.logError('Failed to stop advertising', error: e);
    }
  }

  /// Iniciar browsing (cliente)
  Future<bool> startBrowsing() async {
    try {
      final result = await _channel.invokeMethod('startBrowsing');
      DebugUtils.log('Browsing started', tag: 'MULTIPEER');
      return result as bool;
    } catch (e) {
      DebugUtils.logError('Failed to start browsing', error: e);
      return false;
    }
  }

  /// Parar browsing
  Future<void> stopBrowsing() async {
    try {
      await _channel.invokeMethod('stopBrowsing');
      DebugUtils.log('Browsing stopped', tag: 'MULTIPEER');
    } catch (e) {
      DebugUtils.logError('Failed to stop browsing', error: e);
    }
  }

  /// Convidar peer para conectar
  Future<void> invitePeer(String peerId) async {
    try {
      await _channel.invokeMethod('invitePeer', {
        'peerId': peerId,
      });
      DebugUtils.log('Invited peer: $peerId', tag: 'MULTIPEER');
    } catch (e) {
      DebugUtils.logError('Failed to invite peer', error: e);
    }
  }

  /// Enviar dados para peer
  Future<bool> sendData(String peerId, List<int> data) async {
    try {
      final result = await _channel.invokeMethod('sendData', {
        'peerId': peerId,
        'data': data,
      });
      return result as bool;
    } catch (e) {
      DebugUtils.logError('Failed to send data', error: e);
      return false;
    }
  }

  /// Desconectar de peer
  Future<void> disconnectPeer(String peerId) async {
    try {
      await _channel.invokeMethod('disconnectPeer', {
        'peerId': peerId,
      });
      DebugUtils.log('Disconnected from: $peerId', tag: 'MULTIPEER');
    } catch (e) {
      DebugUtils.logError('Failed to disconnect', error: e);
    }
  }

  /// Processar evento de discovery
  void _handleDiscoveryEvent(Map<dynamic, dynamic> data) {
    final eventType = data['type'] as String;
    
    switch (eventType) {
      case 'peerFound':
        final peerId = data['peerId'] as String;
        final peerName = data['peerName'] as String;
        
        final peer = Peer(
          id: peerId,
          name: peerName,
          lastSeen: DateTime.now(),
          isConnected: false,
        );
        
        _discoveredPeersController.add(peer);
        _connectionStatusController.add('Found peer: $peerName');
        break;

      case 'peerLost':
        final peerId = data['peerId'] as String;
        _connectionStatusController.add('Lost peer: $peerId');
        break;

      case 'peerConnected':
        final peerId = data['peerId'] as String;
        _connectionStatusController.add('Connected to: $peerId');
        break;

      case 'peerDisconnected':
        final peerId = data['peerId'] as String;
        _connectionStatusController.add('Disconnected from: $peerId');
        break;
    }
  }

  /// Processar evento de mensagem
  void _handleMessageEvent(Map<dynamic, dynamic> data) {
    final peerId = data['peerId'] as String;
    final messageData = data['data'] as List<int>;
    
    _messagesController.add({
      'sender_id': peerId,
      'data': messageData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void dispose() {
    stopAdvertising();
    stopBrowsing();
    _discoveredPeersController.close();
    _messagesController.close();
    _connectionStatusController.close();
  }
}

/// Código Swift nativo (ios/Runner/MultipeerHandler.swift)
/// 
/// Este arquivo deve ser criado em ios/Runner/:
/// 
/// ```swift
/// import Flutter
/// import MultipeerConnectivity
/// 
/// class MultipeerHandler: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
///     var session: MCSession!
///     var advertiser: MCNearbyServiceAdvertiser!
///     var browser: MCNearbyServiceBrowser!
///     var peerID: MCPeerID!
///     var serviceType: String = "speew-p2p"
///     
///     var discoveryEventSink: FlutterEventSink?
///     var messagesEventSink: FlutterEventSink?
///     
///     func initialize(displayName: String, serviceType: String) {
///         self.serviceType = serviceType
///         self.peerID = MCPeerID(displayName: displayName)
///         self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
///         self.session.delegate = self
///     }
///     
///     func startAdvertising() {
///         advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
///         advertiser.delegate = self
///         advertiser.startAdvertisingPeer()
///     }
///     
///     func startBrowsing() {
///         browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
///         browser.delegate = self
///         browser.startBrowsingForPeers()
///     }
///     
///     // ... delegates e métodos adicionais
/// }
/// ```
