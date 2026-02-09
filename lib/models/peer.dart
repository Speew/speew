class Peer {
  final String id;
  final String name;
  final DateTime lastSeen;
  bool isConnected;

  Peer({
    required this.id,
    required this.name,
    required this.lastSeen,
    this.isConnected = false,
  });

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
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown',
      lastSeen: map['last_seen'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int)
          : DateTime.now(),
      isConnected: (map['is_connected'] as int?) == 1,
    );
  }

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

  @override
  String toString() => 'Peer(id: $id, name: $name, connected: $isConnected)';
}