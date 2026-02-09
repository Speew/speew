import 'dart:async';
import '../core/utils.dart';

class VideoCallService {
  final Map<String, VideoCall> _activeCalls = {};
  
  final StreamController<VideoCallEvent> _eventController =
      StreamController<VideoCallEvent>.broadcast();

  Stream<VideoCallEvent> get eventStream => _eventController.stream;

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

  Future<bool> acceptCall(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return false;

    try {

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

  Future<void> rejectCall(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return;

    _activeCalls.remove(callId);

    _eventController.add(VideoCallEvent(
      type: VideoCallEventType.callRejected,
      callId: callId,
    ));

    DebugUtils.log('Call rejected: $callId', tag: 'VIDEO_CALL');
  }

  Future<void> endCall(String callId) async {
    final call = _activeCalls.remove(callId);
    if (call == null) return;

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

  Future<void> toggleVideo(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return;

    call.videoEnabled = !call.videoEnabled;

    DebugUtils.log(
      'Video ${call.videoEnabled ? 'enabled' : 'disabled'}',
      tag: 'VIDEO_CALL',
    );
  }

  Future<void> toggleAudio(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return;

    call.audioEnabled = !call.audioEnabled;

    DebugUtils.log(
      'Audio ${call.audioEnabled ? 'enabled' : 'disabled'}',
      tag: 'VIDEO_CALL',
    );
  }

  Future<void> switchCamera(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return;

    call.isFrontCamera = !call.isFrontCamera;

    DebugUtils.log('Camera switched', tag: 'VIDEO_CALL');
  }

  VideoCall? getCall(String callId) {
    return _activeCalls[callId];
  }

  bool get hasActiveCall => _activeCalls.isNotEmpty;

  CallStatistics? getStatistics(String callId) {
    final call = _activeCalls[callId];
    if (call == null) return null;

    return CallStatistics(
      callId: callId,
      duration: call.connectedAt != null
          ? DateTime.now().difference(call.connectedAt!)
          : Duration.zero,
      videoBitrate: 1500, 
      audioBitrate: 64, 
      packetLoss: 0.5, 
      jitter: 10, 
      rtt: 25, 
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
  final int videoBitrate; 
  final int audioBitrate; 
  final double packetLoss; 
  final int jitter; 
  final int rtt; 

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

enum VideoQuality {
  low(320, 240, 500, 'Baixa (320p)'),
  medium(640, 480, 1000, 'Média (480p)'),
  high(1280, 720, 2000, 'Alta (720p)'),
  fullHD(1920, 1080, 3000, 'Full HD (1080p)');

  final int width;
  final int height;
  final int bitrate; 
  final String label;

  const VideoQuality(this.width, this.height, this.bitrate, this.label);
}

class ScreenSharing {
  bool _isSharing = false;
  
  bool get isSharing => _isSharing;

  Future<bool> startSharing() async {
    try {

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