class MeshRoute {
  final String destinationId;
  final List<String> hops; 
  final int hopCount;
  final DateTime timestamp;
  final int quality; 

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
    final hopsStr = map['hops'] as String? ?? '';
    return MeshRoute(
      destinationId: map['destination_id'] as String? ?? '',
      hops: hopsStr.isNotEmpty ? hopsStr.split(',') : [],
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
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
  final List<String> path; 
  final int ttl; 
  final DateTime timestamp;
  final String type; 

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
      id: json['id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      destinationId: json['destination_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      path: json['path'] != null ? List<String>.from(json['path'] as List) : [],
      ttl: json['ttl'] as int? ?? 64,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
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