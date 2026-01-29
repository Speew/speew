class MeshRoute {
  final String destinationId;
  final List<String> hops; // Lista de IDs dos peers intermediários
  final int hopCount;
  final DateTime timestamp;
  final int quality; // 0-100, baseado em latência e confiabilidade

  MeshRoute({
    required this.destinationId,
    required this.hops,
    required this.timestamp,
    this.quality = 50,
  }) : hopCount = hops.length;

  bool get isDirect => hopCount == 1;
  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 5;

  Map<String, dynamic> toMap() {
    return {
      'destination_id': destinationId,
      'hops': hops.join(','),
      'hop_count': hopCount,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'quality': quality,
    };
  }

  factory MeshRoute.fromMap(Map<String, dynamic> map) {
    return MeshRoute(
      destinationId: map['destination_id'] as String,
      hops: (map['hops'] as String).split(','),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      quality: map['quality'] as int? ?? 50,
    );
  }

  MeshRoute copyWith({
    String? destinationId,
    List<String>? hops,
    DateTime? timestamp,
    int? quality,
  }) {
    return MeshRoute(
      destinationId: destinationId ?? this.destinationId,
      hops: hops ?? this.hops,
      timestamp: timestamp ?? this.timestamp,
      quality: quality ?? this.quality,
    );
  }

  @override
  String toString() {
    return 'Route to $destinationId via [${hops.join(' -> ')}] (quality: $quality)';
  }
}

class MeshPacket {
  final String id;
  final String senderId;
  final String destinationId;
  final String content;
  final List<String> path; // Caminho percorrido até agora
  final int ttl; // Time to live (hops restantes)
  final DateTime timestamp;
  final String type; // 'message', 'route_discovery', 'route_reply', 'ack'

  MeshPacket({
    required this.id,
    required this.senderId,
    required this.destinationId,
    required this.content,
    required this.path,
    required this.ttl,
    required this.timestamp,
    this.type = 'message',
  });

  bool get isExpired => ttl <= 0;
  int get hopCount => path.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'destination_id': destinationId,
      'content': content,
      'path': path,
      'ttl': ttl,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type,
    };
  }

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    return MeshPacket(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      destinationId: json['destination_id'] as String,
      content: json['content'] as String,
      path: List<String>.from(json['path'] as List),
      ttl: json['ttl'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      type: json['type'] as String? ?? 'message',
    );
  }

  MeshPacket withDecrementedTTL(String currentNodeId) {
    return MeshPacket(
      id: id,
      senderId: senderId,
      destinationId: destinationId,
      content: content,
      path: [...path, currentNodeId],
      ttl: ttl - 1,
      timestamp: timestamp,
      type: type,
    );
  }

  @override
  String toString() {
    return 'Packet($id) from $senderId to $destinationId via [${path.join(' -> ')}] (TTL: $ttl)';
  }
}
