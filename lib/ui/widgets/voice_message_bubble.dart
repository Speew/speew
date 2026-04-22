import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/voice_message_service.dart';

class VoiceMessageBubble extends StatefulWidget {
  final VoiceMessage voiceMessage;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.voiceMessage,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final VoiceMessageService _service = VoiceMessageService();
  bool _isPlaying = false;

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _service.playVoiceMessage(widget.voiceMessage.filePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.blue : Colors.grey[300],
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          
          IconButton(
            icon: const Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isMe ? Colors.white : Colors.black87,
            ),
            onPressed: _togglePlay,
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            constraints: const BoxConstraints(),
          ),
          
          const SizedBox(width: 8),

          Expanded(
            child: Container(
              height: 30,
              child: CustomPaint(
                painter: WaveformPainter(
                  isMe: widget.isMe,
                  isPlaying: _isPlaying,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 8),

          const Text(
            widget.voiceMessage.formattedDuration,
            style: TextStyle(
              color: widget.isMe ? Colors.white70 : Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final bool isMe;
  final bool isPlaying;

  WaveformPainter({required this.isMe, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isMe ? Colors.white : Colors.black87).withOpacity(0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final barCount = 20;
    final barWidth = size.width / barCount;
    
    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final height = (i % 3 + 1) * 8.0; 
      
      final y1 = size.height / 2 - height / 2;
      final y2 = size.height / 2 + height / 2;
      
      canvas.drawLine(
        Offset(x, y1),
        Offset(x, y2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.isPlaying != isPlaying;
  }
}

class VoiceRecorderButton extends StatefulWidget {
  final void Function(VoiceMessage) onVoiceMessageRecorded;

  const VoiceRecorderButton({
    super.key,
    required this.onVoiceMessageRecorded,
  });

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton> {
  final VoiceMessageService _service = VoiceMessageService();
  bool _isRecording = false;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _durationSubscription = _service.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final started = await _service.startRecording();
    if (started && mounted) {
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _stopRecording() async {
    final voiceMessage = await _service.stopRecording();
    
    if (mounted) {
      setState(() {
        _isRecording = false;
        _duration = Duration.zero;
      });
    }

    if (voiceMessage != null) {
      widget.onVoiceMessageRecorded(voiceMessage);
    }
  }

  void _cancelRecording() {
    _service.cancelRecording();
    setState(() {
      _isRecording = false;
      _duration = Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: const BorderRadius.all(Radius.circular(24)),
        ),
        child: Row(
          children: [
            
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: _cancelRecording,
            ),
            
            const SizedBox(width: 8),

            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            
            const SizedBox(width: 8),

            const Text(
              '${_duration.inMinutes.toString().padLeft(2, '0')}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            
            const Spacer(),

            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed: _stopRecording,
            ),
          ],
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.mic),
      onPressed: _startRecording,
      tooltip: 'Record voice message',
    );
  }
}