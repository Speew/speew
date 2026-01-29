import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import '../models/mesh_route.dart';
import '../core/utils.dart';

class MeshRoutingService {
  // Tabela de rotas: destinationId -> MeshRoute
  final Map<String, MeshRoute> _routingTable = {};
  
  // Cache de pacotes já processados (evita loops)
  final Set<String> _processedPackets = LinkedHashSet();
  
  // Fila de pacotes pendentes para reenvio
  final Queue<MeshPacket> _pendingPackets = Queue();
  
  // Stream de pacotes que precisam ser enviados
  final StreamController<MeshPacket> _outgoingPacketsController =
      StreamController<MeshPacket>.broadcast();
  
  // Stream de mensagens que chegaram ao destino final
  final StreamController<MeshPacket> _deliveredPacketsController =
      StreamController<MeshPacket>.broadcast();
  
  String? _myNodeId;
  
  // Configurações
  static const int maxTTL = 5; // Máximo de hops
  static const int maxProcessedCache = 1000; // Cache de pacotes processados
  static const int routeExpirationMinutes = 5;
  static const int maxPendingPackets = 100;

  // Getters
  Stream<MeshPacket> get outgoingPacketsStream => _outgoingPacketsController.stream;
  Stream<MeshPacket> get deliveredPacketsStream => _deliveredPacketsController.stream;
  Map<String, MeshRoute> get routingTable => Map.unmodifiable(_routingTable);
  int get pendingPacketsCount => _pendingPackets.length;

  /// Inicializar com ID do nó atual
  void initialize(String nodeId) {
    _myNodeId = nodeId;
    DebugUtils.log('Mesh routing initialized for node: $nodeId', tag: 'MESH');
  }

  /// Enviar mensagem através da mesh
  Future<bool> sendMessage({
    required String destinationId,
    required String content,
    String type = 'message',
  }) async {
    if (_myNodeId == null) {
      DebugUtils.logError('Node ID not initialized');
      return false;
    }

    // Criar pacote
    final packet = MeshPacket(
      id: _generatePacketId(),
      senderId: _myNodeId!,
      destinationId: destinationId,
      content: content,
      path: [_myNodeId!],
      ttl: maxTTL,
      timestamp: DateTime.now(),
      type: type,
    );

    return await _routePacket(packet);
  }

  /// Receber e processar pacote da rede
  Future<void> receivePacket(MeshPacket packet) async {
    if (_myNodeId == null) return;

    DebugUtils.log('Received packet: ${packet.id}', tag: 'MESH');

    // Verificar se já processamos este pacote (evita loops)
    if (_processedPackets.contains(packet.id)) {
      DebugUtils.log('Packet already processed, ignoring', tag: 'MESH');
      return;
    }

    // Adicionar ao cache de processados
    _addToProcessedCache(packet.id);

    // Verificar se pacote expirou
    if (packet.isExpired) {
      DebugUtils.log('Packet expired (TTL=0), dropping', tag: 'MESH');
      return;
    }

    // Se este nó é o destino
    if (packet.destinationId == _myNodeId) {
      DebugUtils.log('Packet reached destination!', tag: 'MESH');
      _deliveredPacketsController.add(packet);
      
      // Enviar ACK de volta
      if (packet.type == 'message') {
        _sendAcknowledgment(packet);
      }
      return;
    }

    // Processar tipos especiais de pacote
    if (packet.type == 'route_discovery') {
      _handleRouteDiscovery(packet);
      return;
    }

    if (packet.type == 'route_reply') {
      _handleRouteReply(packet);
      return;
    }

    // Fazer relay do pacote
    await _relayPacket(packet);
  }

  /// Rotear pacote (encontrar melhor rota e enviar)
  Future<bool> _routePacket(MeshPacket packet) async {
    // Verificar se temos rota para o destino
    final route = _routingTable[packet.destinationId];

    if (route != null && !route.isExpired) {
      // Temos rota válida, usar
      DebugUtils.log('Using cached route: $route', tag: 'MESH');
      _outgoingPacketsController.add(packet);
      return true;
    }

    // Não temos rota, fazer broadcast para descoberta
    DebugUtils.log('No route found, initiating route discovery', tag: 'MESH');
    _initiateRouteDiscovery(packet.destinationId);
    
    // Adicionar pacote à fila de pendentes
    _addToPendingQueue(packet);
    return true;
  }

  /// Fazer relay (retransmitir) de um pacote
  Future<void> _relayPacket(MeshPacket packet) async {
    if (_myNodeId == null) return;

    // Decrementar TTL e adicionar nó atual ao caminho
    final relayedPacket = packet.withDecrementedTTL(_myNodeId!);

    DebugUtils.log(
      'Relaying packet ${packet.id} (TTL: ${relayedPacket.ttl})',
      tag: 'MESH',
    );

    // Enviar pacote retransmitido
    _outgoingPacketsController.add(relayedPacket);
  }

  /// Iniciar descoberta de rota
  void _initiateRouteDiscovery(String destinationId) {
    if (_myNodeId == null) return;

    final discoveryPacket = MeshPacket(
      id: _generatePacketId(),
      senderId: _myNodeId!,
      destinationId: destinationId,
      content: 'ROUTE_DISCOVERY',
      path: [_myNodeId!],
      ttl: maxTTL,
      timestamp: DateTime.now(),
      type: 'route_discovery',
    );

    DebugUtils.log(
      'Initiating route discovery for $destinationId',
      tag: 'MESH',
    );

    _outgoingPacketsController.add(discoveryPacket);
  }

  /// Processar pacote de descoberta de rota
  void _handleRouteDiscovery(MeshPacket packet) {
    if (_myNodeId == null) return;

    // Se este nó é o destino, enviar resposta de volta
    if (packet.destinationId == _myNodeId) {
      DebugUtils.log('Route discovery reached destination', tag: 'MESH');
      
      final replyPacket = MeshPacket(
        id: _generatePacketId(),
        senderId: _myNodeId!,
        destinationId: packet.senderId,
        content: jsonEncode({'route': packet.path}),
        path: [_myNodeId!],
        ttl: maxTTL,
        timestamp: DateTime.now(),
        type: 'route_reply',
      );

      _outgoingPacketsController.add(replyPacket);
      return;
    }

    // Senão, fazer relay
    _relayPacket(packet);
  }

  /// Processar resposta de rota
  void _handleRouteReply(MeshPacket packet) {
    if (_myNodeId == null) return;

    try {
      final data = jsonDecode(packet.content) as Map<String, dynamic>;
      final route = List<String>.from(data['route'] as List);

      // Adicionar rota à tabela
      final meshRoute = MeshRoute(
        destinationId: packet.senderId,
        hops: route,
        timestamp: DateTime.now(),
        quality: _calculateRouteQuality(route),
      );

      _routingTable[packet.senderId] = meshRoute;
      
      DebugUtils.log('Route added: $meshRoute', tag: 'MESH');

      // Processar pacotes pendentes para este destino
      _processPendingPackets(packet.senderId);
    } catch (e) {
      DebugUtils.logError('Error handling route reply', error: e);
    }
  }

  /// Enviar acknowledgment de recebimento
  void _sendAcknowledgment(MeshPacket packet) {
    if (_myNodeId == null) return;

    final ackPacket = MeshPacket(
      id: _generatePacketId(),
      senderId: _myNodeId!,
      destinationId: packet.senderId,
      content: jsonEncode({'ack_for': packet.id}),
      path: [_myNodeId!],
      ttl: maxTTL,
      timestamp: DateTime.now(),
      type: 'ack',
    );

    _outgoingPacketsController.add(ackPacket);
  }

  /// Processar pacotes pendentes para um destino
  void _processPendingPackets(String destinationId) {
    final packetsToSend = <MeshPacket>[];
    
    // Encontrar pacotes pendentes para este destino
    final iterator = _pendingPackets.iterator;
    while (iterator.moveNext()) {
      final packet = iterator.current;
      if (packet.destinationId == destinationId) {
        packetsToSend.add(packet);
      }
    }

    // Remover da fila e enviar
    for (final packet in packetsToSend) {
      _pendingPackets.remove(packet);
      _routePacket(packet);
    }

    DebugUtils.log(
      'Processed ${packetsToSend.length} pending packets',
      tag: 'MESH',
    );
  }

  /// Adicionar pacote à fila de pendentes
  void _addToPendingQueue(MeshPacket packet) {
    if (_pendingPackets.length >= maxPendingPackets) {
      // Remover o mais antigo
      _pendingPackets.removeFirst();
    }
    _pendingPackets.add(packet);
  }

  /// Adicionar ao cache de pacotes processados
  void _addToProcessedCache(String packetId) {
    if (_processedPackets.length >= maxProcessedCache) {
      // Remover o mais antigo
      _processedPackets.remove(_processedPackets.first);
    }
    _processedPackets.add(packetId);
  }

  /// Calcular qualidade da rota (0-100)
  int _calculateRouteQuality(List<String> hops) {
    // Quanto menos hops, melhor
    final hopPenalty = hops.length * 10;
    return (100 - hopPenalty).clamp(0, 100);
  }

  /// Gerar ID único para pacote
  String _generatePacketId() {
    return '${_myNodeId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Limpar rotas expiradas
  void cleanExpiredRoutes() {
    _routingTable.removeWhere((key, route) => route.isExpired);
    DebugUtils.log('Cleaned expired routes', tag: 'MESH');
  }

  /// Obter estatísticas da mesh
  Map<String, dynamic> getStatistics() {
    return {
      'node_id': _myNodeId,
      'routes_count': _routingTable.length,
      'pending_packets': _pendingPackets.length,
      'processed_cache_size': _processedPackets.length,
      'routes': _routingTable.values.map((r) => r.toString()).toList(),
    };
  }

  /// Limpar tudo
  void dispose() {
    _routingTable.clear();
    _processedPackets.clear();
    _pendingPackets.clear();
    _outgoingPacketsController.close();
    _deliveredPacketsController.close();
  }
}
