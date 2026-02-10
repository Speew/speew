import 'package:flutter/material.dart';
import '../services/enhanced_typing_service.dart';

/// Typing Helper Mixin
/// Easy integration of typing indicator into any chat widget
mixin TypingHelperMixin {
  final EnhancedTypingService _typingService = EnhancedTypingService();
  
  /// Call this when text field changes
  void onTextChanged(String peerId, String text, {Function()? onSendTyping}) {
    if (text.trim().isEmpty) {
      _typingService.userStoppedTyping(peerId, onSend: onSendTyping);
    } else {
      _typingService.userStartedTyping(peerId, onSend: onSendTyping);
    }
  }

  /// Call this when message is sent
  void onMessageSent(String peerId, {Function()? onSendTyping}) {
    _typingService.userStoppedTyping(peerId, onSend: onSendTyping);
  }

  /// Call this when peer typing event is received
  void onPeerTyping(String peerId, bool isTyping) {
    _typingService.peerIsTyping(peerId, isTyping);
  }

  /// Check if peer is typing
  bool isPeerTyping(String peerId) {
    return _typingService.isTyping(peerId);
  }

  /// Get typing stream
  Stream<TypingEvent> get typingStream => _typingService.typingStream;

  /// Cleanup
  void disposeTyping(String peerId) {
    _typingService.reset(peerId);
  }
}

/// TextField with typing indicator
/// Drop-in replacement for TextField with automatic typing detection
class TypingTextField extends StatefulWidget {
  final String peerId;
  final void Function(String) onChanged;
  final void Function()? onSendTyping;
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const TypingTextField({
    super.key,
    required this.peerId,
    required this.onChanged,
    this.onSendTyping,
    this.controller,
    this.decoration,
    this.maxLines = 1,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<TypingTextField> createState() => _TypingTextFieldState();
}

class _TypingTextFieldState extends State<TypingTextField> with TypingHelperMixin {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    disposeTyping(widget.peerId);
    super.dispose();
  }

  void _handleTextChanged(String text) {
    onTextChanged(widget.peerId, text, onSendTyping: widget.onSendTyping);
    widget.onChanged(text);
  }

  void _handleSubmitted(String text) {
    onMessageSent(widget.peerId, onSendTyping: widget.onSendTyping);
    widget.onSubmitted?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: widget.decoration,
      maxLines: widget.maxLines,
      textInputAction: widget.textInputAction,
      onChanged: _handleTextChanged,
      onSubmitted: _handleSubmitted,
    );
  }
}

/// Example usage widget
class TypingIndicatorExample extends StatefulWidget {
  final String peerId;
  final String peerName;

  const TypingIndicatorExample({
    super.key,
    required this.peerId,
    required this.peerName,
  });

  @override
  State<TypingIndicatorExample> createState() => _TypingIndicatorExampleState();
}

class _TypingIndicatorExampleState extends State<TypingIndicatorExample> with TypingHelperMixin {
  @override
  void dispose() {
    disposeTyping(widget.peerId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Input field
        TypingTextField(
          peerId: widget.peerId,
          onChanged: (text) {
            // Your logic here
          },
          onSendTyping: () {
            // Send typing event to peer via P2P
            // p2pService.sendTypingEvent(peerId, true);
          },
          decoration: const InputDecoration(
            hintText: 'Digite uma mensagem...',
          ),
        ),

        // Typing indicator
        StreamBuilder<TypingEvent>(
          stream: typingStream,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.peerId == widget.peerId) {
              final isTyping = snapshot.data!.isTyping;
              
              if (isTyping) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '${widget.peerName} está digitando...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
            }
            
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
