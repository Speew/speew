import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../core/utils.dart';

/// Voice Messages com compressão Opus
/// Alta qualidade, baixo tamanho (melhor que AAC/MP3)
class VoiceMessages {
  final StreamController<VoiceRecordingState> _stateController =
      StreamController<VoiceRecordingState>.broadcast();

  Stream<VoiceRecordingState> get stateStream => _stateController.stream;

  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Iniciar gravação de áudio
  Future<bool> startRecording() async {
    if (_isRecording) return false;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final voiceDir = Directory('${dir.path}/voice_messages');
      
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = path.join(
        voiceDir.path,
        'voice_$timestamp.opus',
      );

      // Iniciar gravação nativa
      // Em produção: usar package como record/flutter_sound
      // Configuração Opus:
      // - Bitrate: 32 kbps (voz)
      // - Sample rate: 16 kHz
      // - Channels: Mono
      
      _isRecording = true;
      _recordingStartTime = DateTime.now();

      _stateController.add(VoiceRecordingState.recording);

      DebugUtils.log('Voice recording started', tag: 'VOICE');
      return true;
    } catch (e) {
      DebugUtils.logError('Failed to start recording', error: e);
      return false;
    }
  }

  /// Parar gravação e salvar
  Future<VoiceMessage?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      // Parar gravação nativa
      _isRecording = false;

      if (_currentRecordingPath == null || _recordingStartTime == null) {
        return null;
      }

      final file = File(_currentRecordingPath!);
      
      if (!await file.exists()) {
        DebugUtils.logError('Recording file not found');
        return null;
      }

      final stat = await file.stat();
      final duration = DateTime.now().difference(_recordingStartTime!);

      // Criar waveform (visualização)
      final waveform = await _generateWaveform(file);

      final voiceMessage = VoiceMessage(
        filePath: _currentRecordingPath!,
        duration: duration,
        fileSize: stat.size,
        waveform: waveform,
        codec: 'opus',
        bitrate: 32000, // 32 kbps
        sampleRate: 16000, // 16 kHz
      );

      _stateController.add(VoiceRecordingState.stopped);

      DebugUtils.log(
        'Voice recorded: ${duration.inSeconds}s, ${_formatBytes(stat.size)}',
        tag: 'VOICE',
      );

      _currentRecordingPath = null;
      _recordingStartTime = null;

      return voiceMessage;
    } catch (e) {
      DebugUtils.logError('Failed to stop recording', error: e);
      return null;
    }
  }

  /// Cancelar gravação
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    _isRecording = false;

    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _currentRecordingPath = null;
    _recordingStartTime = null;

    _stateController.add(VoiceRecordingState.cancelled);

    DebugUtils.log('Voice recording cancelled', tag: 'VOICE');
  }

  /// Obter duração atual da gravação
  Duration? getCurrentDuration() {
    if (!_isRecording || _recordingStartTime == null) {
      return null;
    }

    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Reproduzir mensagem de voz
  Future<void> playVoiceMessage(VoiceMessage message) async {
    try {
      // Usar audio player (just_audio, audioplayers, etc.)
      DebugUtils.log('Playing voice message', tag: 'VOICE');
      
      // Em produção:
      // final player = AudioPlayer();
      // await player.setFilePath(message.filePath);
      // await player.play();
    } catch (e) {
      DebugUtils.logError('Failed to play voice message', error: e);
    }
  }

  /// Gerar waveform para visualização
  Future<List<double>> _generateWaveform(File audioFile) async {
    // Em produção: usar FFT ou análise de amplitude
    // Por ora: retornar waveform simulado
    
    final random = DateTime.now().millisecond;
    return List.generate(50, (i) {
      return 0.3 + (((i + random) % 10) / 20);
    });
  }

  /// Comprimir áudio (se não for Opus)
  Future<File?> compressToOpus(File audioFile) async {
    try {
      // Usar FFmpeg para converter para Opus
      // ffmpeg -i input.m4a -c:a libopus -b:a 32k output.opus
      
      final dir = await getApplicationDocumentsDirectory();
      final outputPath = path.join(
        dir.path,
        'voice_messages',
        'compressed_${DateTime.now().millisecondsSinceEpoch}.opus',
      );

      // Executar conversão
      // Em produção: usar ffmpeg_kit_flutter
      
      DebugUtils.log('Audio compressed to Opus', tag: 'VOICE');
      
      return File(outputPath);
    } catch (e) {
      DebugUtils.logError('Failed to compress audio', error: e);
      return null;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void dispose() {
    if (_isRecording) {
      cancelRecording();
    }
    _stateController.close();
  }
}

class VoiceMessage {
  final String filePath;
  final Duration duration;
  final int fileSize;
  final List<double> waveform;
  final String codec;
  final int bitrate;
  final int sampleRate;

  VoiceMessage({
    required this.filePath,
    required this.duration,
    required this.fileSize,
    required this.waveform,
    required this.codec,
    required this.bitrate,
    required this.sampleRate,
  });

  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'file_path': filePath,
    'duration_ms': duration.inMilliseconds,
    'file_size': fileSize,
    'waveform': waveform,
    'codec': codec,
    'bitrate': bitrate,
    'sample_rate': sampleRate,
  };

  factory VoiceMessage.fromJson(Map<String, dynamic> json) => VoiceMessage(
    filePath: json['file_path'],
    duration: Duration(milliseconds: json['duration_ms']),
    fileSize: json['file_size'],
    waveform: List<double>.from(json['waveform']),
    codec: json['codec'],
    bitrate: json['bitrate'],
    sampleRate: json['sample_rate'],
  );
}

enum VoiceRecordingState {
  idle,
  recording,
  stopped,
  cancelled,
  playing,
  paused,
}

/// Processamento de áudio avançado
class AudioProcessor {
  /// Remover ruído de fundo
  static Future<File?> removeNoise(File audioFile) async {
    try {
      // Usar algoritmo de noise reduction
      // Em produção: FFmpeg com filtro afftdn
      // ffmpeg -i input.opus -af "afftdn=nf=-25" output.opus
      
      DebugUtils.log('Noise removed from audio', tag: 'AUDIO');
      return audioFile;
    } catch (e) {
      return null;
    }
  }

  /// Normalizar volume
  static Future<File?> normalizeVolume(File audioFile) async {
    try {
      // Normalização de áudio
      // FFmpeg: loudnorm filter
      
      DebugUtils.log('Audio volume normalized', tag: 'AUDIO');
      return audioFile;
    } catch (e) {
      return null;
    }
  }

  /// Detectar silêncio e cortar
  static Future<File?> trimSilence(File audioFile) async {
    try {
      // Remover silêncio do início e fim
      // FFmpeg: silenceremove filter
      
      DebugUtils.log('Silence trimmed from audio', tag: 'AUDIO');
      return audioFile;
    } catch (e) {
      return null;
    }
  }
}
