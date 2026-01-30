import 'dart:async';
import '../core/utils.dart';

/// Video Calls P2P usando WebRTC
/// Chamadas de vídeo sem servidor (truly P2P)
class VideoCallService {
  final Map<String, VideoCall> _activeCalls = {};
  
  final StreamController<VideoCallEvent> _eventController =
      StreamController<VideoCallEvent>.broadcast();

  Stream<VideoCallEvent> get eventStream => _eventController.stream;

  /// Iniciar chamada de vídeo
  Future<VideoCall?> initiateCall({
    required String peerId,
    required String peerName,
    bool videoEnabled = true,
    bool audioEnabled = true,
  }) async {
    try {
      final callId = _generateCallId();

      final call = VideoCall(
        callId: callId,
        peerId: peerId,
        peerName: peerName,
        isOutgoing: true,
        videoEnabled: videoEnabled,
        audioEnabled: audioEnabled,
      );

      _activeCalls[callId] = call;

      // Criar oferta WebRTC
      // final offer = await _createOffer(call);
      
      // Enviar oferta ao peer via P2P
      // await p2p.send(peerId, offer);

      _eventController.add(VideoCallEvent(
        type: VideoCallEventType.callInitiated,
        callId: callId,
      ));

      DebugUtils.log('Video call initiated to $peerName', tag: 'VIDEO_CALL');

      return call;
    } catch (e) {
      DebugUtils.logError('Failed to initiate call', error: e);
      return null;
    }
  }

  /// Receber chamada de entrada
  Future<void> receiveCall({
    required String callId,
    required String peerId,
    required String peerName,
    required Map<String, dynamic> offer,
  }) async {
    final call = VideoCall(
      callId: callId,
      peerId: peerId,
      peerName: peerName,
      isOutgoing: false,
      videoEnabled: true,
      audioEnabled: true,
    );

    _activeCalls[callId] = call;

    _eventController.add(VideoCallEvent(
      type: VideoCallEventType.incomingCall,
      callId: callId,
      peerName: peerName,
    ));

    DebugUtils.log('Incoming call from $peerName', tag: 'VIDEO_CALL');
  }

  /// Aceitar chamada
  Future<bool> acceptCall(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return false;

    try {
      // Criar resposta WebRTC
      // final answer = await _createAnswer(call);
      
      // Enviar resposta ao peer
      // await p2p.send(call.peerId, answer);

      call.state = CallState.connected;
      call.connectedAt = DateTime.now();

      _eventController.add(VideoCallEvent(
        type: VideoCallEventType.callConnected,
        callId: callId,
      ));

      DebugUtils.log('Call accepted: $callId', tag: 'VIDEO_CALL');

      return true;
    } catch (e) {
      DebugUtils.logError('Failed to accept call', error: e);
      return false;
    }
  }

  /// Rejeitar chamada
  Future<void> rejectCall(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return;

    // Enviar rejeição ao peer
    // await p2p.send(call.peerId, {'type': 'reject'});

    _activeCalls.remove(callId);

    _eventController.add(VideoCallEvent(
      type: VideoCallEventType.callRejected,
      callId: callId,
    ));

    DebugUtils.log('Call rejected: $callId', tag: 'VIDEO_CALL');
  }

  /// Encerrar chamada
  Future<void> endCall(String callId) async {
    final call = _activeCalls.remove(callId);
    if (call == null) return;

    // Fechar conexão WebRTC
    // await _closeConnection(call);

    // Notificar peer
    // await p2p.send(call.peerId, {'type': 'hangup'});

    final duration = call.connectedAt != null
        ? DateTime.now().difference(call.connectedAt!)
        : Duration.zero;

    _eventController.add(VideoCallEvent(
      type: VideoCallEventType.callEnded,
      callId: callId,
      duration: duration,
    ));

    DebugUtils.log(
      'Call ended: $callId (${duration.inSeconds}s)',
      tag: 'VIDEO_CALL',
    );
  }

  /// Alternar vídeo
  Future<void> toggleVideo(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return;

    call.videoEnabled = !call.videoEnabled;

    // Atualizar track de vídeo
    // await _updateVideoTrack(call);

    DebugUtils.log(
      'Video ${call.videoEnabled ? 'enabled' : 'disabled'}',
      tag: 'VIDEO_CALL',
    );
  }

  /// Alternar áudio
  Future<void> toggleAudio(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return;

    call.audioEnabled = !call.audioEnabled;

    // Atualizar track de áudio
    // await _updateAudioTrack(call);

    DebugUtils.log(
      'Audio ${call.audioEnabled ? 'enabled' : 'disabled'}',
      tag: 'VIDEO_CALL',
    );
  }

  /// Alternar câmera (frontal/traseira)
  Future<void> switchCamera(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return;

    call.isFrontCamera = !call.isFrontCamera;

    // Trocar fonte de vídeo
    // await _switchVideoSource(call);

    DebugUtils.log('Camera switched', tag: 'VIDEO_CALL');
  }

  /// Obter chamada ativa
  VideoCall? getCall(String callId) {
    return _activeCalls[callId];
  }

  /// Verificar se há chamada ativa
  bool get hasActiveCall => _activeCalls.isNotEmpty;

  /// Obter estatísticas da chamada
  CallStatistics? getStatistics(String callId) {
    final call = _activeCalls[callId];
    if (call == null) return null;

    // Em produção: obter stats reais do WebRTC
    return CallStatistics(
      callId: callId,
      duration: call.connectedAt != null
          ? DateTime.now().difference(call.connectedAt!)
          : Duration.zero,
      videoBitrate: 1500, // kbps
      audioBitrate: 64, // kbps
      packetLoss: 0.5, // %
      jitter: 10, // ms
      rtt: 25, // ms (round-trip time)
    );
  }

  String _generateCallId() {
    return 'call_${DateTime.now().millisecondsSinceEpoch}';
  }

  void dispose() {
    for (final callId in _activeCalls.keys.toList()) {
      endCall(callId);
    }
    _eventController.close();
  }
}

class VideoCall {
  final String callId;
  final String peerId;
  final String peerName;
  final bool isOutgoing;
  final DateTime startedAt;
  DateTime? connectedAt;
  CallState state;
  bool videoEnabled;
  bool audioEnabled;
  bool isFrontCamera;

  VideoCall({
    required this.callId,
    required this.peerId,
    required this.peerName,
    required this.isOutgoing,
    required this.videoEnabled,
    required this.audioEnabled,
    this.isFrontCamera = true,
    DateTime? startedAt,
    this.connectedAt,
    this.state = CallState.connecting,
  }) : startedAt = startedAt ?? DateTime.now();

  Duration get duration {
    if (connectedAt == null) return Duration.zero;
    return DateTime.now().difference(connectedAt!);
  }

  String get durationFormatted {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

enum CallState {
  connecting,
  ringing,
  connected,
  reconnecting,
  ended,
}

class VideoCallEvent {
  final VideoCallEventType type;
  final String callId;
  final String? peerName;
  final Duration? duration;

  VideoCallEvent({
    required this.type,
    required this.callId,
    this.peerName,
    this.duration,
  });
}

enum VideoCallEventType {
  callInitiated,
  incomingCall,
  callConnected,
  callRejected,
  callEnded,
  callFailed,
}

class CallStatistics {
  final String callId;
  final Duration duration;
  final int videoBitrate; // kbps
  final int audioBitrate; // kbps
  final double packetLoss; // %
  final int jitter; // ms
  final int rtt; // ms (round-trip time)

  CallStatistics({
    required this.callId,
    required this.duration,
    required this.videoBitrate,
    required this.audioBitrate,
    required this.packetLoss,
    required this.jitter,
    required this.rtt,
  });

  String get quality {
    if (packetLoss < 1 && jitter < 30 && rtt < 50) {
      return 'Excelente';
    } else if (packetLoss < 3 && jitter < 50 && rtt < 100) {
      return 'Boa';
    } else if (packetLoss < 5 && jitter < 100 && rtt < 200) {
      return 'Regular';
    } else {
      return 'Ruim';
    }
  }
}

/// Configurações de qualidade de vídeo
enum VideoQuality {
  low(320, 240, 500, 'Baixa (320p)'),
  medium(640, 480, 1000, 'Média (480p)'),
  high(1280, 720, 2000, 'Alta (720p)'),
  fullHD(1920, 1080, 3000, 'Full HD (1080p)');

  final int width;
  final int height;
  final int bitrate; // kbps
  final String label;

  const VideoQuality(this.width, this.height, this.bitrate, this.label);
}

/// Screen Sharing (compartilhamento de tela)
class ScreenSharing {
  bool _isSharing = false;
  
  bool get isSharing => _isSharing;

  Future<bool> startSharing() async {
    try {
      // Iniciar captura de tela
      // Em Android: MediaProjection API
      // Em iOS: ReplayKit (iOS 12+)
      
      _isSharing = true;
      DebugUtils.log('Screen sharing started', tag: 'SCREEN_SHARE');
      
      return true;
    } catch (e) {
      DebugUtils.logError('Failed to start screen sharing', error: e);
      return false;
    }
  }

  Future<void> stopSharing() async {
    _isSharing = false;
    DebugUtils.log('Screen sharing stopped', tag: 'SCREEN_SHARE');
  }
}
