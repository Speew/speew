import 'dart:async';
import '../core/utils.dart';

class AutoDestructMessages {
  final Map<String, Timer> _destructTimers = {};
  final Map<String, DateTime> _readTimestamps = {};
  
  final StreamController<String> _messageDestructedController =
      StreamController<String>.broadcast();

  Stream<String> get messageDestructedStream => _messageDestructedController.stream;

  void scheduleDestruction({
    required String messageId,
    required Duration afterRead,
    required Function onDestruct,
  }) {
    DebugUtils.log(
      'Message $messageId will self-destruct in ${afterRead.inSeconds}s after read',
      tag: 'DESTRUCT',
    );

    _readTimestamps[messageId] = DateTime.now();

  }

  void markAsRead(String messageId, {required Function onDestruct}) {
    if (!_readTimestamps.containsKey(messageId)) {
      return; 
    }

    final config = _getDestructConfig(messageId);
    if (config == null) return;

    DebugUtils.log(
      'Message read! Destructing in ${config.inSeconds}s',
      tag: 'DESTRUCT',
    );

    _destructTimers[messageId]?.cancel();

    _destructTimers[messageId] = Timer(config, () {
      _destroyMessage(messageId, onDestruct);
    });
  }

  void scheduleTimedDestruction({
    required String messageId,
    required Duration after,
    required Function onDestruct,
  }) {
    DebugUtils.log(
      'Message $messageId will self-destruct in ${after.inSeconds}s',
      tag: 'DESTRUCT',
    );

    _destructTimers[messageId] = Timer(after, () {
      _destroyMessage(messageId, onDestruct);
    });
  }

  void _destroyMessage(String messageId, Function onDestruct) {
    DebugUtils.log('💥 Message $messageId SELF-DESTRUCTED', tag: 'DESTRUCT');

    onDestruct();

    _messageDestructedController.add(messageId);

    _destructTimers.remove(messageId);
    _readTimestamps.remove(messageId);
  }

  void cancelDestruction(String messageId) {
    _destructTimers[messageId]?.cancel();
    _destructTimers.remove(messageId);
    _readTimestamps.remove(messageId);

    DebugUtils.log('Destruction cancelled for $messageId', tag: 'DESTRUCT');
  }

  Duration? _getDestructConfig(String messageId) {

    return const Duration(seconds: 10);
  }

  Duration? getTimeRemaining(String messageId) {
    final timer = _destructTimers[messageId];
    if (timer == null || !timer.isActive) return null;

    final readTime = _readTimestamps[messageId];
    if (readTime == null) return null;

    final config = _getDestructConfig(messageId);
    if (config == null) return null;

    final elapsed = DateTime.now().difference(readTime);
    final remaining = config - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool isAutoDestruct(String messageId) {
    return _readTimestamps.containsKey(messageId) ||
           _destructTimers.containsKey(messageId);
  }

  void dispose() {
    for (final timer in _destructTimers.values) {
      timer.cancel();
    }
    _destructTimers.clear();
    _readTimestamps.clear();
    _messageDestructedController.close();
  }
}

enum DestructPreset {
  immediate(Duration(seconds: 0), 'Imediatamente'),
  fiveSeconds(Duration(seconds: 5), '5 segundos'),
  tenSeconds(Duration(seconds: 10), '10 segundos'),
  thirtySeconds(Duration(seconds: 30), '30 segundos'),
  oneMinute(Duration(minutes: 1), '1 minuto'),
  fiveMinutes(Duration(minutes: 5), '5 minutos'),
  oneHour(Duration(hours: 1), '1 hora'),
  oneDay(Duration(hours: 24), '1 dia'),
  oneWeek(Duration(days: 7), '1 semana');

  final Duration duration;
  final String label;

  const DestructPreset(this.duration, this.label);
}

class ScreenshotDetection {
  final StreamController<DateTime> _screenshotController =
      StreamController<DateTime>.broadcast();

  Stream<DateTime> get screenshotStream => _screenshotController.stream;

  void startDetection() {

    DebugUtils.log('Screenshot detection started', tag: 'SCREENSHOT');
  }

  void _onScreenshotDetected() {
    final timestamp = DateTime.now();
    
    DebugUtils.log('⚠️ SCREENSHOT DETECTED!', tag: 'SCREENSHOT');
    _screenshotController.add(timestamp);
  }

  void dispose() {
    _screenshotController.close();
  }
}

class RecordingDetection {
  bool _isRecording = false;
  final StreamController<bool> _recordingController =
      StreamController<bool>.broadcast();

  Stream<bool> get recordingStream => _recordingController.stream;
  bool get isRecording => _isRecording;

  void checkRecording() {

    final wasRecording = _isRecording;

    if (_isRecording && !wasRecording) {
      DebugUtils.log('⚠️ SCREEN RECORDING STARTED!', tag: 'RECORDING');
      _recordingController.add(true);
    } else if (!_isRecording && wasRecording) {
      DebugUtils.log('Screen recording stopped', tag: 'RECORDING');
      _recordingController.add(false);
    }
  }

  void dispose() {
    _recordingController.close();
  }
}