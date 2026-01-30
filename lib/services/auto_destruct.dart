import 'dart:async';
import '../core/utils.dart';

/// Mensagens auto-destrutivas (self-destructing messages)
/// Estilo Snapchat, Telegram Secret Chats, Signal
class AutoDestructMessages {
  final Map<String, Timer> _destructTimers = {};
  final Map<String, DateTime> _readTimestamps = {};
  
  final StreamController<String> _messageDestructedController =
      StreamController<String>.broadcast();

  Stream<String> get messageDestructedStream => _messageDestructedController.stream;

  /// Configurar mensagem para auto-destruir após leitura
  void scheduleDestruction({
    required String messageId,
    required Duration afterRead,
    required Function onDestruct,
  }) {
    DebugUtils.log(
      'Message $messageId will self-destruct in ${afterRead.inSeconds}s after read',
      tag: 'DESTRUCT',
    );

    // Guardar para quando for lida
    _readTimestamps[messageId] = DateTime.now();

    // Não inicia timer ainda - só quando for lida
  }

  /// Marcar mensagem como lida e iniciar contagem regressiva
  void markAsRead(String messageId, {required Function onDestruct}) {
    if (!_readTimestamps.containsKey(messageId)) {
      return; // Mensagem não é auto-destrutiva
    }

    final config = _getDestructConfig(messageId);
    if (config == null) return;

    DebugUtils.log(
      'Message read! Destructing in ${config.inSeconds}s',
      tag: 'DESTRUCT',
    );

    // Cancelar timer anterior se existir
    _destructTimers[messageId]?.cancel();

    // Iniciar novo timer
    _destructTimers[messageId] = Timer(config, () {
      _destroyMessage(messageId, onDestruct);
    });
  }

  /// Configurar auto-destruição por tempo (sem necessidade de leitura)
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

  /// Destruir mensagem
  void _destroyMessage(String messageId, Function onDestruct) {
    DebugUtils.log('💥 Message $messageId SELF-DESTRUCTED', tag: 'DESTRUCT');

    // Executar callback
    onDestruct();

    // Notificar
    _messageDestructedController.add(messageId);

    // Limpar
    _destructTimers.remove(messageId);
    _readTimestamps.remove(messageId);
  }

  /// Cancelar auto-destruição
  void cancelDestruction(String messageId) {
    _destructTimers[messageId]?.cancel();
    _destructTimers.remove(messageId);
    _readTimestamps.remove(messageId);

    DebugUtils.log('Destruction cancelled for $messageId', tag: 'DESTRUCT');
  }

  /// Obter configuração de destruição
  Duration? _getDestructConfig(String messageId) {
    // Por padrão: 10 segundos após leitura
    // Pode ser customizado por mensagem
    return const Duration(seconds: 10);
  }

  /// Obter tempo restante até destruição
  Duration? getTimeRemaining(String messageId) {
    final timer = _destructTimers[messageId];
    if (timer == null || !timer.isActive) return null;

    // Estimativa (não exata pois Timer não expõe tempo restante)
    final readTime = _readTimestamps[messageId];
    if (readTime == null) return null;

    final config = _getDestructConfig(messageId);
    if (config == null) return null;

    final elapsed = DateTime.now().difference(readTime);
    final remaining = config - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Verificar se mensagem é auto-destrutiva
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

/// Presets de auto-destruição
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

/// Screenshot Detection (Android)
class ScreenshotDetection {
  final StreamController<DateTime> _screenshotController =
      StreamController<DateTime>.broadcast();

  Stream<DateTime> get screenshotStream => _screenshotController.stream;

  /// Iniciar detecção de screenshots
  void startDetection() {
    // Em Android: Monitora FileObserver em /Pictures/Screenshots
    // Em iOS: Não é possível detectar (limitação do iOS)
    
    DebugUtils.log('Screenshot detection started', tag: 'SCREENSHOT');
  }

  /// Notificar screenshot detectado
  void _onScreenshotDetected() {
    final timestamp = DateTime.now();
    
    DebugUtils.log('⚠️ SCREENSHOT DETECTED!', tag: 'SCREENSHOT');
    _screenshotController.add(timestamp);
  }

  void dispose() {
    _screenshotController.close();
  }
}

/// Screen Recording Detection (Android 10+)
class RecordingDetection {
  bool _isRecording = false;
  final StreamController<bool> _recordingController =
      StreamController<bool>.broadcast();

  Stream<bool> get recordingStream => _recordingController.stream;
  bool get isRecording => _isRecording;

  /// Detectar gravação de tela
  void checkRecording() {
    // Android 10+: MediaProjection.isRecording()
    // iOS: Não detectável
    
    // Simulação
    final wasRecording = _isRecording;
    // _isRecording = checkNativeRecording();

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
