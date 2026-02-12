import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/peer.dart';
import '../services/storage_service.dart';
import '../services/p2p_service.dart';

class ChatProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final P2PService _p2p = P2PService();

  final Map<String, List<Message>> _messagesByPeer = {};
  StreamSubscription<Message>? _messageSubscription;

  Future<void> initialize() async {
    _messageSubscription = _p2p.messageStream.listen((message) {
      _addMessage(message);
      _storage.saveMessage(message);
    });
  }

  Future<List<Message>> getMessages(String peerId) async {
    if (_messagesByPeer.containsKey(peerId)) {
      return _messagesByPeer[peerId]!;
    }

    final messages = await _storage.getMessages(peerId);
    _messagesByPeer[peerId] = messages;
    return messages;
  }

  Future<void> sendMessage(String content, Peer peer) async {
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'me',
      receiverId: peer.id,
      content: content,
      timestamp: DateTime.now(),
      type: MessageType.text,
      status: MessageStatus.sending,
    );

    _addMessage(message);
    await _storage.saveMessage(message);

    try {
      await _p2p.sendMessage(message, peer.id);
      
      final updatedMessage = message.copyWith(status: MessageStatus.sent);
      _updateMessage(updatedMessage);
      await _storage.saveMessage(updatedMessage);
    } catch (e) {
      debugPrint('Error sending message: $e');
      
      final failedMessage = message.copyWith(status: MessageStatus.failed);
      _updateMessage(failedMessage);
      await _storage.saveMessage(failedMessage);
    }
  }

  void _addMessage(Message message) {
    final peerId = message.senderId == 'me' ? message.receiverId : message.senderId;
    
    if (!_messagesByPeer.containsKey(peerId)) {
      _messagesByPeer[peerId] = [];
    }

    _messagesByPeer[peerId]!.add(message);
    notifyListeners();
  }

  void _updateMessage(Message message) {
    final peerId = message.senderId == 'me' ? message.receiverId : message.senderId;
    
    if (_messagesByPeer.containsKey(peerId)) {
      final index = _messagesByPeer[peerId]!.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messagesByPeer[peerId]![index] = message;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
