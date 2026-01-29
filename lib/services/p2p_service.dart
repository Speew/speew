import 'dart:async';
import 'dart:convert';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/peer.dart';
import '../models/mesh_route.dart';
import 'mesh_routing_service.dart';
import '../core/utils.dart';

class P2PService {
  final MeshRoutingService _meshRouting = MeshRoutingService();
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
  bool _meshEnabled = false; // Mesh multi-hop habilitado

  // Getters
  Stream<Peer> get discoveredPeersStream => _discoveredPeersController.stream;
  Stream<Map<String, dynamic>> get messagesStream => _messagesController.stream;
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;
  
  List<Peer> get discoveredPeers => _discoveredPeers.values.toList();
  List<String> get connectedPeerIds => List.from(_connectedPeers);
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  bool get isMeshEnabled => _meshEnabled;

  // Inicializar mesh routing
  void initializeMesh(String deviceId) {
    _myDeviceId = deviceId;
    _meshRouting.initialize(deviceId);
    _meshEnabled = true;
    
    // Escutar pacotes outgoing do mesh routing
    _meshRouting.outgoingPacketsStream.listen(_sendMeshPacket);
    
    // Escutar pacotes entregues
    _meshRouting.deliveredPacketsStream.listen(_handleDeliveredPacket);
    
    DebugUtils.log('Mesh routing initialized', tag: 'P2P');
  }

  // Enviar mensagem via mesh
  Future<bool> sendMeshMessage(String destinationId, String content) async {
    if (!_meshEnabled) {
      DebugUtils.log('Mesh not enabled, using direct send', tag: 'P2P');
      return await sendMessage(destinationId, content);
    }

    return await _meshRouting.sendMessage(
      destinationId: destinationId,
      content: content,
    );
  }

  // Enviar pacote mesh pela rede
  Future<void> _sendMeshPacket(MeshPacket packet) async {
    try {
      // Determinar próximo hop
      final nextHop = _getNextHop(packet);
      
      if (nextHop == null) {
        DebugUtils.log('No next hop for packet, broadcasting', tag: 'P2P');
        // Broadcast para todos os peers conectados
        for (final peerId in _connectedPeers) {
          await _sendPacketToPeer(peerId, packet);
        }
      } else {
        // Enviar para próximo hop específico
        await _sendPacketToPeer(nextHop, packet);
      }
    } catch (e) {
      DebugUtils.logError('Error sending mesh packet', error: e);
    }
  }

  // Enviar pacote para um peer específico
  Future<void> _sendPacketToPeer(String peerId, MeshPacket packet) async {
    final payload = jsonEncode({
      'type': 'mesh_packet',
      'packet': packet.toJson(),
    });

    await _nearby.sendBytesPayload(peerId, utf8.encode(payload));
    DebugUtils.log('Sent mesh packet to $peerId', tag: 'P2P');
  }

  // Determinar próximo hop para um pacote
  String? _getNextHop(MeshPacket packet) {
    // Verificar se destino está diretamente conectado
    if (_connectedPeers.contains(packet.destinationId)) {
      return packet.destinationId;
    }

    // Consultar tabela de rotas
    final route = _meshRouting.routingTable[packet.destinationId];
    if (route != null && route.hops.isNotEmpty) {
      // Retornar primeiro hop da rota
      return route.hops.first;
    }

    // Sem rota conhecida
    return null;
  }

  // Processar pacote mesh entregue
  void _handleDeliveredPacket(MeshPacket packet) {
    DebugUtils.log('Mesh packet delivered: ${packet.id}', tag: 'P2P');
    
    // Adicionar à stream de mensagens para ser processado pelo ChatProvider
    _messagesController.add({
      'sender_id': packet.senderId,
      'content': packet.content,
      'timestamp': packet.timestamp.millisecondsSinceEpoch,
      'via_mesh': true,
      'hop_count': packet.hopCount,
    });
  }

  // Obter estatísticas mesh
  Map<String, dynamic> getMeshStatistics() {
    if (!_meshEnabled) {
      return {'enabled': false};
    }
    return _meshRouting.getStatistics();
  }

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
        
        // Verificar se é pacote mesh
        if (decoded['type'] == 'mesh_packet') {
          if (_meshEnabled) {
            final packetData = decoded['packet'] as Map<String, dynamic>;
            final packet = MeshPacket.fromJson(packetData);
            _meshRouting.receivePacket(packet);
          }
          return;
        }
        
        // Mensagem normal (não-mesh)
        if (decoded['type'] == 'message') {
          _messagesController.add({
            'sender_id': endpointId,
            'content': decoded['content'],
            'timestamp': decoded['timestamp'],
            'via_mesh': false,
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
    _meshRouting.dispose();
    _discoveredPeersController.close();
    _messagesController.close();
    _connectionStatusController.close();
  }
}
