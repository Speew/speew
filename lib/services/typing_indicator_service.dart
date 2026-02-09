import 'dart:async';
import 'package:flutter/foundation.dart';

/// Typing Indicator Service
/// Shows when a peer is typing (like WhatsApp)
class TypingIndicatorService {
  static final TypingIndicatorService _instance = TypingIndicatorService._internal();
  factory TypingIndicatorService() => _instance;
  TypingIndicatorService._internal();

  final Map<String, Timer?> _typingTimers = {};
  final Map<String, bool> _typingStatus = {};
  
  final _typingController = StreamController<Map<String, bool>>.broadcast();
  Stream<Map<String, bool>> get typingStream => _typingController.stream;

  /// Start typing indicator for a peer
  void startTyping(String peerId) {
    // Cancel existing timer
    _typingTimers[peerId]?.cancel();
    
    // Set typing status
    _typingStatus[peerId] = true;
    _notifyListeners();
    
    // Auto-stop after 3 seconds
    _typingTimers[peerId] = Timer(const Duration(seconds: 3), () {
      stopTyping(peerId);
    });
  }

  /// Stop typing indicator for a peer
  void stopTyping(String peerId) {
    _typingTimers[peerId]?.cancel();
    _typingTimers.remove(peerId);
    _typingStatus[peerId] = false;
    _notifyListeners();
  }

  /// Check if peer is typing
  bool isTyping(String peerId) {
    return _typingStatus[peerId] ?? false;
  }

  void _notifyListeners() {
    _typingController.add(Map.from(_typingStatus));
  }

  void dispose() {
    for (var timer in _typingTimers.values) {
      timer?.cancel();
    }
    _typingTimers.clear();
    _typingStatus.clear();
    _typingController.close();
  }
}
