import 'message.dart';

class Group {
  final String id;
  final String name;
  final String? description;
  final String creatorId;
  final List<String> memberIds;
  final DateTime createdAt;
  final String? avatarPath;
  final String? groupKey;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.creatorId,
    required this.memberIds,
    required this.createdAt,
    this.avatarPath,
    this.groupKey,
  });

  int get memberCount => memberIds.length;
  bool isAdmin(String userId) => userId == creatorId;
  bool isMember(String userId) => memberIds.contains(userId);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'creator_id': creatorId,
      'member_ids': memberIds.join(','),
      'created_at': createdAt.millisecondsSinceEpoch,
      'avatar_path': avatarPath,
      'group_key': groupKey,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    final memberIdsStr = map['member_ids'] as String? ?? '';
    return Group(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed Group',
      description: map['description'] as String?,
      creatorId: map['creator_id'] as String? ?? '',
      memberIds: memberIdsStr.isNotEmpty ? memberIdsStr.split(',') : [],
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.now(),
      avatarPath: map['avatar_path'] as String?,
      groupKey: map['group_key'] as String?,
    );
  }

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? creatorId,
    List<String>? memberIds,
    DateTime? createdAt,
    String? avatarPath,
    String? groupKey,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      creatorId: creatorId ?? this.creatorId,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
      avatarPath: avatarPath ?? this.avatarPath,
      groupKey: groupKey ?? this.groupKey,
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
  final Map<String, bool> deliveredTo;

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
