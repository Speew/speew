import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/utils.dart';

class VoiceCallService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  final StreamController<CallState> _callStateController =
      StreamController<CallState>.broadcast();
  final StreamController<CallQuality> _qualityController =
      StreamController<CallQuality>.broadcast();

  Stream<CallState> get callStateStream => _callStateController.stream;
  Stream<CallQuality> get qualityStream => _qualityController.stream;
  
  CallState _currentState = CallState.idle;
  DateTime? _callStartTime;

  CallState get currentState => _currentState;
  bool get isInCall => _currentState == CallState.connected;

  Future<void> initialize() async {
    DebugUtils.log('Voice call service initialized', tag: 'VOICE');
  }

  Future<Map<String, dynamic>> startCall() async {
    try {
      _updateState(CallState.calling);

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'sampleRate': 48000, 
        },
        'video': false,
      });

      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'} 
        ],
      });

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _setupPeerConnectionListeners();

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      await _peerConnection!.setLocalDescription(offer);

      DebugUtils.log('Call offer created', tag: 'VOICE');

      return {
        'type': 'offer',
        'sdp': offer.sdp,
      };
    } catch (e) {
      DebugUtils.logError('Failed to start call', error: e);
      _updateState(CallState.failed);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> answerCall(Map<String, dynamic> offer) async {
    try {
      _updateState(CallState.ringing);

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'sampleRate': 48000,
        },
        'video': false,
      });

      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'}
        ],
      });

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _setupPeerConnectionListeners();

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      await _peerConnection!.setLocalDescription(answer);

      _updateState(CallState.connecting);

      DebugUtils.log('Call answered', tag: 'VOICE');

      return {
        'type': 'answer',
        'sdp': answer.sdp,
      };
    } catch (e) {
      DebugUtils.logError('Failed to answer call', error: e);
      _updateState(CallState.failed);
      rethrow;
    }
  }

  Future<void> completeConnection(Map<String, dynamic> answer) async {
    try {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );

      DebugUtils.log('Call connection completed', tag: 'VOICE');
    } catch (e) {
      DebugUtils.logError('Failed to complete connection', error: e);
      _updateState(CallState.failed);
    }
  }

  Future<void> addIceCandidate(Map<String, dynamic> candidate) async {
    try {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        ),
      );
    } catch (e) {
      DebugUtils.logError('Failed to add ICE candidate', error: e);
    }
  }

  void _setupPeerConnectionListeners() {
    
    _peerConnection!.onIceCandidate = (candidate) {
      
      DebugUtils.log('ICE candidate generated', tag: 'VOICE');
    };

    _peerConnection!.onTrack = (event) {
      if (event.track.kind == 'audio') {
        _remoteStream = event.streams[0];
        _updateState(CallState.connected);
        _callStartTime = DateTime.now();
        
        DebugUtils.log('Remote audio track received', tag: 'VOICE');
      }
    };

    _peerConnection!.onConnectionState = (state) {
      DebugUtils.log('Connection state: $state', tag: 'VOICE');
      
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _updateState(CallState.connected);
        _startQualityMonitoring();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _updateState(CallState.failed);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _updateState(CallState.disconnected);
      }
    };
  }

  void _startQualityMonitoring() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isInCall) {
        timer.cancel();
        return;
      }

      _peerConnection!.getStats().then((stats) {
        _analyzeStats(stats);
      });
    });
  }

  void _analyzeStats(List<StatsReport> stats) {
    for (final report in stats) {
      if (report.type == 'inbound-rtp' && report.values['kind'] == 'audio') {
        final packetsLost = report.values['packetsLost'] ?? 0;
        final packetsReceived = report.values['packetsReceived'] ?? 0;
        final jitter = report.values['jitter'] ?? 0.0;

        final lossRate = packetsReceived > 0
            ? (packetsLost / packetsReceived) * 100
            : 0.0;

        final quality = CallQuality(
          packetsLost: packetsLost,
          packetsReceived: packetsReceived,
          lossRate: lossRate,
          jitter: jitter,
          duration: _getCallDuration(),
        );

        _qualityController.add(quality);
      }
    }
  }

  Future<void> toggleMute() async {
    if (_localStream == null) return;

    final audioTracks = _localStream!.getAudioTracks();
    for (final track in audioTracks) {
      track.enabled = !track.enabled;
    }

    DebugUtils.log('Microphone ${audioTracks[0].enabled ? "unmuted" : "muted"}', tag: 'VOICE');
  }

  Future<void> toggleSpeaker(bool enable) async {
    await Helper.setSpeakerphoneOn(enable);
    DebugUtils.log('Speaker ${enable ? "on" : "off"}', tag: 'VOICE');
  }

  Future<void> endCall() async {
    _updateState(CallState.ended);

    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();

    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _callStartTime = null;

    DebugUtils.log('Call ended', tag: 'VOICE');
  }

  Duration _getCallDuration() {
    if (_callStartTime == null) return Duration.zero;
    return DateTime.now().difference(_callStartTime!);
  }

  void _updateState(CallState state) {
    _currentState = state;
    _callStateController.add(state);
  }

  void dispose() {
    endCall();
    _callStateController.close();
    _qualityController.close();
  }
}

enum CallState {
  idle,
  calling,
  ringing,
  connecting,
  connected,
  disconnected,
  ended,
  failed,
}

class CallQuality {
  final int packetsLost;
  final int packetsReceived;
  final double lossRate;
  final double jitter;
  final Duration duration;

  CallQuality({
    required this.packetsLost,
    required this.packetsReceived,
    required this.lossRate,
    required this.jitter,
    required this.duration,
  });

  String get qualityRating {
    if (lossRate < 1.0 && jitter < 30) return 'Excelente';
    if (lossRate < 3.0 && jitter < 50) return 'Boa';
    if (lossRate < 5.0 && jitter < 100) return 'Regular';
    return 'Ruim';
  }

  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}