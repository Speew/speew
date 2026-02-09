import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

import '../models/message.dart';
import '../models/peer.dart';
import '../models/group.dart';
import '../services/p2p_service.dart';
import '../services/crypto_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/file_transfer_service.dart';
import '../core/error/error_handler.dart';

class ChatProvider with ChangeNotifier {
  final P2PService _p2pService;
  final CryptoService _cryptoService;
  final StorageService _storageService;
  final NotificationService _notificationService;
  final FileTransferService _fileTransferService;
  
  final Map<String, List<Message>> _chatMessages = {};
  final Map<String, bool> _typingIndicators = {};
  final Map<String, int> _unreadCounts = {};
  final Map<String, Timer> _typingTimers = {};
  
  StreamSubscription? _messageStreamSub;
  StreamSubscription? _typingStreamSub;
  
  Message? _replyingTo;
  bool _isLoading = false;
  String? _error;
  
  ChatProvider({
    required P2PService p2pService,
    required CryptoService cryptoService,
    required StorageService storageService,
    required NotificationService notificationService,
    required FileTransferService fileTransferService,
  })  : _p2pService = p2pService,
        _cryptoService = cryptoService,
        _storageService = storageService,
        _notificationService = notificationService,
        _fileTransferService = fileTransferService {
    _init();
  }
  
  // Getters
  List<Message> getMessages(String chatId) {
    return _chatMessages[chatId] ?? [];
  }
  
  bool isTyping(String peerId) {
    return _typingIndicators[peerId] ?? false;
  }
  
  int getUnreadCount(String chatId) {
    return _unreadCounts[chatId] ?? 0;
  }
  
  int get totalUnreadCount {
    return _unreadCounts.values.fold(0, (sum, count) => sum + count);
  }
  
  Message? get replyingTo => _replyingTo;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Inicialização
  void _init() {
    _messageStreamSub = _p2pService.messageStream.listen(_handleIncomingMessage);
    _typingStreamSub = _p2pService.typingStream.listen(_handleTypingIndicator);
    _loadMessagesFromStorage();
  }
  
  Future<void> _loadMessagesFromStorage() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final chats = await _storageService.getAllChats();
      
      for (final chat in chats) {
        final messages = await _storageService.getMessages(chat.id);
        _chatMessages[chat.id] = messages;
        
        final unread = messages.where((m) => !m.isRead && !m.isSentByMe).length;
        _unreadCounts[chat.id] = unread;
      }
      
      _error = null;
    } catch (e, stack) {
      _error = 'Failed to load messages';
      ErrorHandler.handleError(e, stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Envio de mensagens
  Future<bool> sendMessage({
    required String content,
    required String chatId,
    Peer? peer,
    Group? group,
    String type = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        senderId: _p2pService.currentUserId,
        receiverId: peer?.id ?? group?.id ?? '',
        timestamp: DateTime.now(),
        type: type,
        status: 'pending',
        isSentByMe: true,
        metadata: metadata,
        replyTo: _replyingTo?.id,
      );
      
      // Adiciona à lista local
      _addMessage(chatId, message);
      
      // Encripta mensagem
      final encrypted = await _cryptoService.encryptMessage(
        message.content,
        peer?.publicKey ?? group?.groupKey ?? '',
      );
      
      // Envia via P2P
      final sent = await _p2pService.sendMessage(
        peerId: peer?.id ?? group?.id ?? '',
        message: encrypted,
        isGroup: group != null,
      );
      
      if (sent) {
        message.status = 'sent';
        await _storageService.saveMessage(message);
        _updateMessage(chatId, message);
        _replyingTo = null;
        return true;
      } else {
        message.status = 'failed';
        _updateMessage(chatId, message);
        return false;
      }
    } catch (e, stack) {
      ErrorHandler.handleError(e, stack);
      return false;
    }
  }
  
  // Envio de arquivo
  Future<bool> sendFile({
    required String filePath,
    required String chatId,
    required Peer peer,
    String? caption,
  }) async {
    try {
      final result = await _fileTransferService.sendFile(
        filePath: filePath,
        peerId: peer.id,
        caption: caption,
      );
      
      if (result.success) {
        final message = Message(
          id: result.messageId!,
          content: caption ?? 'File',
          senderId: _p2pService.currentUserId,
          receiverId: peer.id,
          timestamp: DateTime.now(),
          type: result.fileType!,
          status: 'sent',
          isSentByMe: true,
          metadata: {
            'fileName': result.fileName,
            'fileSize': result.fileSize,
            'filePath': filePath,
          },
        );
        
        _addMessage(chatId, message);
        await _storageService.saveMessage(message);
        return true;
      }
      
      return false;
    } catch (e, stack) {
      ErrorHandler.handleError(e, stack);
      return false;
    }
  }
  
  // Recebimento de mensagens
  void _handleIncomingMessage(Map<String, dynamic> data) async {
    try {
      final senderId = data['senderId'] as String;
      final encryptedContent = data['content'] as String;
      final type = data['type'] as String? ?? 'text';
      final metadata = data['metadata'] as Map<String, dynamic>?;
      
      // Desencripta
      final decrypted = await _cryptoService.decryptMessage(
        encryptedContent,
        senderId,
      );
      
      final message = Message(
        id: data['id'] as String,
        content: decrypted,
        senderId: senderId,
        receiverId: _p2pService.currentUserId,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          data['timestamp'] as int,
        ),
        type: type,
        status: 'delivered',
        isSentByMe: false,
        metadata: metadata,
      );
      
      final chatId = senderId; // ou group id
      _addMessage(chatId, message);
      
      // Incrementa contador não lido
      _unreadCounts[chatId] = (_unreadCounts[chatId] ?? 0) + 1;
      
      // Salva no storage
      await _storageService.saveMessage(message);
      
      // Mostra notificação
      await _notificationService.showMessageNotification(
        title: data['senderName'] ?? 'New Message',
        body: message.content,
        payload: chatId,
      );
      
      notifyListeners();
    } catch (e, stack) {
      ErrorHandler.handleError(e, stack);
    }
  }
  
  // Indicador de digitação
  void sendTypingIndicator(String peerId, bool isTyping) {
    _p2pService.sendTypingIndicator(peerId, isTyping);
  }
  
  void _handleTypingIndicator(Map<String, dynamic> data) {
    final peerId = data['peerId'] as String;
    final isTyping = data['isTyping'] as bool;
    
    _typingIndicators[peerId] = isTyping;
    notifyListeners();
    
    if (isTyping) {
      // Cancela timer anterior se existir
      _typingTimers[peerId]?.cancel();
      
      // Cria novo timer para auto-stop
      _typingTimers[peerId] = Timer(const Duration(seconds: 5), () {
        if (_typingIndicators[peerId] ?? false) {
          _typingIndicators[peerId] = false;
          notifyListeners();
        }
        _typingTimers.remove(peerId);
      });
    }
  }
  
  // Marcar como lida
  Future<void> markAsRead(String chatId) async {
    try {
      final messages = _chatMessages[chatId] ?? [];
      
      for (final message in messages) {
        if (!message.isRead && !message.isSentByMe) {
          message.status = MessageStatus.read;
          await _storageService.updateMessage(message);
        }
      }
      
      _unreadCounts[chatId] = 0;
      notifyListeners();
    } catch (e, stack) {
      ErrorHandler.handleError(e, stack);
    }
  }
  
  // Deletar mensagem
  Future<bool> deleteMessage(String chatId, String messageId) async {
    try {
      await _storageService.deleteMessage(messageId);
      
      final messages = _chatMessages[chatId];
      if (messages != null) {
        messages.removeWhere((m) => m.id == messageId);
        notifyListeners();
      }
      
      return true;
    } catch (e, stack) {
      ErrorHandler.handleError(e, stack);
      return false;
    }
  }
  
  // Responder mensagem
  void setReplyTo(Message? message) {
    _replyingTo = message;
    notifyListeners();
  }
  
  void cancelReply() {
    _replyingTo = null;
    notifyListeners();
  }
  
  // Helpers
  void _addMessage(String chatId, Message message) {
    if (!_chatMessages.containsKey(chatId)) {
      _chatMessages[chatId] = [];
    }
    
    _chatMessages[chatId]!.add(message);
    _chatMessages[chatId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    notifyListeners();
  }
  
  void _updateMessage(String chatId, Message message) {
    final messages = _chatMessages[chatId];
    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        messages[index] = message;
        notifyListeners();
      }
    }
  }
  
  // Buscar mensagens
  List<Message> searchMessages(String query) {
    final allMessages = _chatMessages.values.expand((list) => list).toList();
    
    return allMessages.where((message) {
      return message.content.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }
  
  // Limpar chat
  Future<bool> clearChat(String chatId) async {
    try {
      final messages = _chatMessages[chatId] ?? [];
      
      for (final message in messages) {
        await _storageService.deleteMessage(message.id);
      }
      
      _chatMessages[chatId] = [];
      _unreadCounts[chatId] = 0;
      
      notifyListeners();
      return true;
    } catch (e, stack) {
      ErrorHandler.handleError(e, stack);
      return false;
    }
  }
  
  @override
  void dispose() {
    _messageStreamSub?.cancel();
    _typingStreamSub?.cancel();
    
    // Cancela todos os typing timers
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    
    _chatMessages.clear();
    _typingIndicators.clear();
    _unreadCounts.clear();
    super.dispose();
  }
}
