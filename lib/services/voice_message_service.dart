import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceMessageService {
  static final VoiceMessageService _instance = VoiceMessageService._internal();
  factory VoiceMessageService() => _instance;
  VoiceMessageService._internal();

  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _durationTimer;
  Duration _currentDuration = Duration.zero;

  final _durationController = StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;

  bool get isRecording => _isRecording;
  Duration get currentDuration => _currentDuration;

  Future<bool> startRecording() async {
    
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('❌ Microphone permission denied');
      return false;
    }

    try {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _currentDuration = Duration.zero;

      _startDurationTimer();

      debugPrint('🎤 Recording started');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      _isRecording = false;
      return false;
    }
  }

  Future<VoiceMessage?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      _isRecording = false;
      _durationTimer?.cancel();

      final duration = _currentDuration;

      final filePath = await _saveRecording();

      debugPrint('🎤 Recording stopped: ${duration.inSeconds}s');

      return VoiceMessage(
        filePath: filePath,
        duration: duration,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      return null;
    }
  }

  void cancelRecording() {
    if (!_isRecording) return;

    _isRecording = false;
    _durationTimer?.cancel();
    _currentDuration = Duration.zero;

    debugPrint('🎤 Recording cancelled');
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        if (_recordingStartTime != null) {
          _currentDuration = DateTime.now().difference(_recordingStartTime!);
          _durationController.add(_currentDuration);
        }
      },
    );
  }

  Future<String> _saveRecording() async {
    final appDir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory('${appDir.path}/voice_messages');
    
    if (!await voiceDir.exists()) {
      await voiceDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${voiceDir.path}/voice_$timestamp.m4a';

    final file = File(filePath);
    await file.writeAsString('voice_data'); 

    return filePath;
  }

  Future<void> playVoiceMessage(String filePath) async {
    debugPrint('▶️ Playing voice message: $filePath');
    
  }

  Future<void> deleteVoiceMessage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Voice message deleted');
      }
    } catch (e) {
      debugPrint('❌ Error deleting voice message: $e');
    }
  }

  void dispose() {
    _durationTimer?.cancel();
    _durationController.close();
  }
}

class VoiceMessage {
  final String filePath;
  final Duration duration;
  final DateTime timestamp;
  bool isPlaying;

  VoiceMessage({
    required this.filePath,
    required this.duration,
    required this.timestamp,
    this.isPlaying = false,
  });

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}