enum MessageType {
  text,
  image,
  voice,
  file,
  location,
}

enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
}

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  MessageStatus status;
  final String? filePath;
  final int? fileSize;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.status = MessageStatus.pending,
    this.filePath,
    this.fileSize,
  });

  bool get isRead => status == MessageStatus.read;
  bool get isSentByMe => senderId == 'me'; // TODO: use actual user ID
  bool get isPending => status == MessageStatus.pending;
  bool get isFailed => status == MessageStatus.failed;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type.index,
      'status': status.index,
      'file_path': filePath,
      'file_size': fileSize,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    final typeIndex = map['type'] as int? ?? 0;
    final statusIndex = map['status'] as int? ?? 0;
    
    return Message(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      content: map['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      type: typeIndex >= 0 && typeIndex < MessageType.values.length 
          ? MessageType.values[typeIndex]
          : MessageType.text,
      status: statusIndex >= 0 && statusIndex < MessageStatus.values.length
          ? MessageStatus.values[statusIndex]
          : MessageStatus.pending,
      filePath: map['file_path'] as String?,
      fileSize: map['file_size'] as int?,
    );
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    MessageType? type,
    MessageStatus? status,
    String? filePath,
    int? fileSize,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}