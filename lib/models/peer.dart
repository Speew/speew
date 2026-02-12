class Peer {
  final String id;
  final String name;
  final DateTime lastSeen;
  final bool isConnected;

  const Peer({
    required this.id,
    required this.name,
    required this.lastSeen,
    this.isConnected = false,
  });

  Peer copyWith({
    String? id,
    String? name,
    DateTime? lastSeen,
    bool? isConnected,
  }) {
    return Peer(
      id: id ?? this.id,
      name: name ?? this.name,
      lastSeen: lastSeen ?? this.lastSeen,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'last_seen': lastSeen.millisecondsSinceEpoch,
      'is_connected': isConnected ? 1 : 0,
    };
  }

  factory Peer.fromMap(Map<String, dynamic> map) {
    return Peer(
      id: map['id'] as String,
      name: map['name'] as String,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int),
      isConnected: (map['is_connected'] as int) == 1,
    );
  }
}
