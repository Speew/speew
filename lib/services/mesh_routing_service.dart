import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import '../models/mesh_route.dart';
import 'p2p_service.dart';

class MeshRoutingService {
  final P2PService _p2pService;

  MeshRoutingService({required P2PService p2pService}) : _p2pService = p2pService;

  final Map<String, MeshRoute> _routingTable = {};
  final Set<String> _processedPackets = LinkedHashSet();
  final Queue<MeshPacket> _pendingPackets = Queue();
  final Map<String, Timer> _routeTimers = {};

  final StreamController<int> _routeCountController = StreamController<int>.broadcast();

  String? _myNodeId;

  static const int maxTTL = 5;
  static const int maxProcessedCache = 1000;
  static const int routeExpirationMinutes = 5;
  static const int maxPendingPackets = 100;

  Stream<int> get routeCountStream => _routeCountController.stream;
  Map<String, MeshRoute> get routingTable => Map.unmodifiable(_routingTable);
  int get pendingPacketsCount => _pendingPackets.length;

  void initialize(String nodeId) {
    _myNodeId = nodeId;
    _startRouteCleanup();
  }

  Future<bool> sendMessage({
    required String destinationId,
    required String content,
    String type = 'message',
  }) async {
    if (_myNodeId == null) return false;

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

  Future<void> receivePacket(MeshPacket packet) async {
    if (_myNodeId == null) return;

    if (_processedPackets.contains(packet.id)) return;

    _addToProcessedCache(packet.id);

    if (packet.isExpired) return;

    if (packet.destinationId == _myNodeId) {
      _handleDeliveredPacket(packet);
      return;
    }

    if (packet.type == 'route_discovery') {
      _handleRouteDiscovery(packet);
      return;
    }

    if (packet.type == 'route_reply') {
      _handleRouteReply(packet);
      return;
    }

    await _relayPacket(packet);
  }

  Future<bool> _routePacket(MeshPacket packet) async {
    final route = _routingTable[packet.destinationId];

    if (route != null && !route.isExpired) {
      await _sendViaRoute(packet, route);
      return true;
    }

    _initiateRouteDiscovery(packet.destinationId);
    _addToPendingQueue(packet);
    return true;
  }

  Future<void> _sendViaRoute(MeshPacket packet, MeshRoute route) async {
    if (route.hops.length <= 1) {
      await _p2pService.sendMessage(peerId: packet.destinationId, message: packet.toJson());
    } else {
      final nextHop = route.hops[1];
      await _p2pService.sendMessage(peerId: nextHop, message: packet.toJson());
    }
  }

  Future<void> _relayPacket(MeshPacket packet) async {
    if (_myNodeId == null) return;

    final relayedPacket = packet.withDecrementedTTL(_myNodeId!);
    
    final route = _routingTable[packet.destinationId];
    if (route != null) {
      await _sendViaRoute(relayedPacket, route);
    } else {
      for (final peer in _p2pService.connectedPeers) {
        if (!packet.path.contains(peer.id)) {
          await _p2pService.sendMessage(peerId: peer.id, message: relayedPacket.toJson());
        }
      }
    }
  }

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

    for (final peer in _p2pService.connectedPeers) {
      _p2pService.sendMessage(peerId: peer.id, message: discoveryPacket.toJson());
    }
  }

  void _handleRouteDiscovery(MeshPacket packet) {
    if (_myNodeId == null) return;

    if (packet.destinationId == _myNodeId) {
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

      _p2pService.sendMessage(peerId: packet.path.last, message: replyPacket.toJson());
      return;
    }

    _relayPacket(packet);
  }

  void _handleRouteReply(MeshPacket packet) {
    if (_myNodeId == null) return;

    try {
      final data = jsonDecode(packet.content) as Map<String, dynamic>;
      final route = List<String>.from(data['route'] as List);

      final meshRoute = MeshRoute(
        destinationId: packet.senderId,
        hops: route,
        timestamp: DateTime.now(),
        quality: _calculateRouteQuality(route),
      );

      _routingTable[packet.senderId] = meshRoute;
      _startRouteExpiration(packet.senderId);
      _routeCountController.add(_routingTable.length);

      _processPendingPackets(packet.senderId);
    } catch (e) {
      // Error handling
    }
  }

  void _handleDeliveredPacket(MeshPacket packet) {
    if (packet.type == 'message') {
      _sendAcknowledgment(packet);
    }
  }

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

    _p2pService.sendMessage(peerId: packet.path.last, message: ackPacket.toJson());
  }

  void _processPendingPackets(String destinationId) {
    final packetsToSend = <MeshPacket>[];

    for (final packet in _pendingPackets) {
      if (packet.destinationId == destinationId) {
        packetsToSend.add(packet);
      }
    }

    for (final packet in packetsToSend) {
      _pendingPackets.remove(packet);
      _routePacket(packet);
    }
  }

  void _addToPendingQueue(MeshPacket packet) {
    if (_pendingPackets.length >= maxPendingPackets) {
      _pendingPackets.removeFirst();
    }
    _pendingPackets.add(packet);
  }

  void _addToProcessedCache(String packetId) {
    if (_processedPackets.length >= maxProcessedCache) {
      _processedPackets.remove(_processedPackets.first);
    }
    _processedPackets.add(packetId);
  }

  int _calculateRouteQuality(List<String> hops) {
    final hopPenalty = hops.length * 10;
    return (100 - hopPenalty).clamp(0, 100);
  }

  String _generatePacketId() {
    return '${_myNodeId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _startRouteExpiration(String destinationId) {
    _routeTimers[destinationId]?.cancel();
    _routeTimers[destinationId] = Timer(
      const Duration(minutes: routeExpirationMinutes),
      () {
        _routingTable.remove(destinationId);
        _routeCountController.add(_routingTable.length);
      },
    );
  }

  void _startRouteCleanup() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      _routingTable.removeWhere((key, route) => route.isExpired);
      _routeCountController.add(_routingTable.length);
    });
  }

  void cleanExpiredRoutes() {
    _routingTable.removeWhere((key, route) => route.isExpired);
    _routeCountController.add(_routingTable.length);
  }

  Map<String, dynamic> getStatistics() {
    return {
      'node_id': _myNodeId,
      'routes_count': _routingTable.length,
      'pending_packets': _pendingPackets.length,
      'processed_cache_size': _processedPackets.length,
      'routes': _routingTable.values.map((r) => r.toString()).toList(),
    };
  }

  void dispose() {
    _routingTable.clear();
    _processedPackets.clear();
    _pendingPackets.clear();
    for (final timer in _routeTimers.values) {
      timer.cancel();
    }
    _routeCountController.close();
  }
}