import 'dart:async';
import 'package:flutter/foundation.dart';

/// Enhanced Typing Indicator Service
/// Improved version with debounce, network efficiency, and better UX
class EnhancedTypingService {
  static final EnhancedTypingService _instance = EnhancedTypingService._internal();
  factory EnhancedTypingService() => _instance;
  EnhancedTypingService._internal();

  final Map<String, Timer?> _typingTimers = {};
  final Map<String, Timer?> _sendTimers = {};
  final Map<String, bool> _typingStatus = {};
  final Map<String, DateTime?> _lastSent = {};
  
  final _typingController = StreamController<TypingEvent>.broadcast();
  Stream<TypingEvent> get typingStream => _typingController.stream;

  // Configuration
  static const Duration _typingTimeout = Duration(seconds: 3);
  static const Duration _sendDebounce = Duration(milliseconds: 800);
  static const Duration _minSendInterval = Duration(seconds: 2);

  /// User started typing
  /// Uses debounce to avoid sending too many "typing" events
  void userStartedTyping(String peerId, {Function()? onSend}) {
    // Update local status immediately
    _setLocalTyping(peerId, true);

    // Cancel existing send timer
    _sendTimers[peerId]?.cancel();

    // Debounce sending to network
    _sendTimers[peerId] = Timer(_sendDebounce, () {
      _sendTypingEvent(peerId, true, onSend);
    });

    // Auto-stop timer
    _typingTimers[peerId]?.cancel();
    _typingTimers[peerId] = Timer(_typingTimeout, () {
      userStoppedTyping(peerId);
    });
  }

  /// User stopped typing
  void userStoppedTyping(String peerId, {Function()? onSend}) {
    _sendTimers[peerId]?.cancel();
    _typingTimers[peerId]?.cancel();
    
    _setLocalTyping(peerId, false);
    _sendTypingEvent(peerId, false, onSend);
  }

  /// Peer is typing (received from network)
  void peerIsTyping(String peerId, bool isTyping) {
    _setLocalTyping(peerId, isTyping);

    if (isTyping) {
      // Auto-stop after timeout
      _typingTimers[peerId]?.cancel();
      _typingTimers[peerId] = Timer(_typingTimeout, () {
        _setLocalTyping(peerId, false);
      });
    } else {
      _typingTimers[peerId]?.cancel();
    }
  }

  /// Send typing event to network (with rate limiting)
  void _sendTypingEvent(String peerId, bool isTyping, Function()? callback) {
    // Rate limiting: don't send too frequently
    final lastSent = _lastSent[peerId];
    if (lastSent != null) {
      final elapsed = DateTime.now().difference(lastSent);
      if (elapsed < _minSendInterval && isTyping) {
        return; // Skip to avoid spam
      }
    }

    _lastSent[peerId] = DateTime.now();
    callback?.call();
  }

  /// Update local typing status
  void _setLocalTyping(String peerId, bool isTyping) {
    _typingStatus[peerId] = isTyping;
    _typingController.add(TypingEvent(
      peerId: peerId,
      isTyping: isTyping,
      timestamp: DateTime.now(),
    ));
  }

  /// Check if peer is typing
  bool isTyping(String peerId) {
    return _typingStatus[peerId] ?? false;
  }

  /// Get all typing peers
  List<String> getTypingPeers() {
    return _typingStatus.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }

  /// Reset typing for a peer
  void reset(String peerId) {
    _typingTimers[peerId]?.cancel();
    _sendTimers[peerId]?.cancel();
    _typingStatus.remove(peerId);
    _lastSent.remove(peerId);
  }

  /// Clear all
  void clearAll() {
    for (var timer in _typingTimers.values) {
      timer?.cancel();
    }
    for (var timer in _sendTimers.values) {
      timer?.cancel();
    }
    _typingTimers.clear();
    _sendTimers.clear();
    _typingStatus.clear();
    _lastSent.clear();
  }

  void dispose() {
    clearAll();
    _typingController.close();
  }
}

/// Typing Event
class TypingEvent {
  final String peerId;
  final bool isTyping;
  final DateTime timestamp;

  TypingEvent({
    required this.peerId,
    required this.isTyping,
    required this.timestamp,
  });
}
