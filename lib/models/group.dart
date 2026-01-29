class Group {
  final String id;
  final String name;
  final String creatorId;
  final List<String> memberIds;
  final DateTime createdAt;
  final String? avatarPath;

  Group({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.memberIds,
    required this.createdAt,
    this.avatarPath,
  });

  int get memberCount => memberIds.length;
  bool isAdmin(String userId) => userId == creatorId;
  bool isMember(String userId) => memberIds.contains(userId);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'creator_id': creatorId,
      'member_ids': memberIds.join(','),
      'created_at': createdAt.millisecondsSinceEpoch,
      'avatar_path': avatarPath,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      creatorId: map['creator_id'] as String,
      memberIds: (map['member_ids'] as String).split(','),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      avatarPath: map['avatar_path'] as String?,
    );
  }

  Group copyWith({
    String? id,
    String? name,
    String? creatorId,
    List<String>? memberIds,
    DateTime? createdAt,
    String? avatarPath,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }

  @override
  String toString() => 'Group($name, ${memberIds.length} members)';
}

class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final String? imageUrl;
  final Map<String, bool> deliveredTo; // peerId -> delivered

  GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.imageUrl,
    Map<String, bool>? deliveredTo,
  }) : deliveredTo = deliveredTo ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'sender_id': senderId,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type.name,
      'image_url': imageUrl,
      'delivered_to': deliveredTo.entries.map((e) => '${e.key}:${e.value}').join(','),
    };
  }

  factory GroupMessage.fromMap(Map<String, dynamic> map) {
    final deliveredToStr = map['delivered_to'] as String? ?? '';
    final deliveredTo = <String, bool>{};
    
    if (deliveredToStr.isNotEmpty) {
      for (final entry in deliveredToStr.split(',')) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          deliveredTo[parts[0]] = parts[1] == 'true';
        }
      }
    }

    return GroupMessage(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      type: MessageType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MessageType.text,
      ),
      imageUrl: map['image_url'] as String?,
      deliveredTo: deliveredTo,
    );
  }
}

enum MessageType {
  text,
  image,
  system,
}
