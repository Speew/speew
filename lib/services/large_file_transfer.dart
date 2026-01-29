import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../core/utils.dart';

class LargeFileTransfer {
  static const int chunkSize = 64 * 1024; // 64KB chunks
  static const int maxFileSize = 1024 * 1024 * 1024; // 1GB max
  
  final Map<String, FileTransferSession> _activeSessions = {};
  
  final StreamController<FileTransferProgress> _progressController =
      StreamController<FileTransferProgress>.broadcast();
  
  Stream<FileTransferProgress> get progressStream => _progressController.stream;

  /// Preparar arquivo para envio
  Future<FileMetadata> prepareFile(File file) async {
    final stat = await file.stat();
    
    if (stat.size > maxFileSize) {
      throw Exception('File too large. Max ${maxFileSize ~/ (1024 * 1024)}MB');
    }

    final transferId = _generateTransferId();
    final fileName = path.basename(file.path);
    final totalChunks = (stat.size / chunkSize).ceil();
    
    // Calcular hash do arquivo
    final fileHash = await _calculateFileHash(file);

    final metadata = FileMetadata(
      transferId: transferId,
      fileName: fileName,
      fileSize: stat.size,
      totalChunks: totalChunks,
      fileHash: fileHash,
      mimeType: _getMimeType(fileName),
    );

    _activeSessions[transferId] = FileTransferSession(
      metadata: metadata,
      filePath: file.path,
      direction: TransferDirection.sending,
    );

    DebugUtils.log(
      'File prepared: $fileName (${_formatBytes(stat.size)}, $totalChunks chunks)',
      tag: 'FILE',
    );

    return metadata;
  }

  /// Obter chunk específico
  Future<FileChunk> getChunk(String transferId, int chunkIndex) async {
    final session = _activeSessions[transferId];
    if (session == null) throw Exception('Session not found');

    final file = File(session.filePath);
    final offset = chunkIndex * chunkSize;
    
    final randomAccess = await file.open(mode: FileMode.read);
    
    try {
      await randomAccess.setPosition(offset);
      final remaining = session.metadata.fileSize - offset;
      final length = remaining < chunkSize ? remaining : chunkSize;
      final data = await randomAccess.read(length);

      // Calcular hash do chunk
      final chunkHash = sha256.convert(data).toString();

      return FileChunk(
        transferId: transferId,
        chunkIndex: chunkIndex,
        data: Uint8List.fromList(data),
        chunkHash: chunkHash,
        isLast: chunkIndex == session.metadata.totalChunks - 1,
      );
    } finally {
      await randomAccess.close();
    }
  }

  /// Iniciar recepção de arquivo
  Future<String> startReceiving(FileMetadata metadata) async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${dir.path}/downloads');
    
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final filePath = path.join(downloadsDir.path, metadata.fileName);
    
    _activeSessions[metadata.transferId] = FileTransferSession(
      metadata: metadata,
      filePath: filePath,
      direction: TransferDirection.receiving,
      receivedChunks: {},
      file: await File(filePath).create(),
    );

    DebugUtils.log('Receiving: ${metadata.fileName}', tag: 'FILE');

    return filePath;
  }

  /// Processar chunk recebido
  Future<bool> receiveChunk(FileChunk chunk) async {
    final session = _activeSessions[chunk.transferId];
    if (session == null) throw Exception('Session not found');

    // Verificar hash do chunk
    final calculatedHash = sha256.convert(chunk.data).toString();
    if (calculatedHash != chunk.chunkHash) {
      DebugUtils.logError('Chunk hash mismatch!');
      return false;
    }

    final file = File(session.filePath);
    final randomAccess = await file.open(mode: FileMode.writeOnlyAppend);
    
    try {
      final offset = chunk.chunkIndex * chunkSize;
      await randomAccess.setPosition(offset);
      await randomAccess.writeFrom(chunk.data);
      
      session.receivedChunks!.add(chunk.chunkIndex);
      
      // Emitir progresso
      final progress = session.receivedChunks!.length / session.metadata.totalChunks;
      
      _progressController.add(FileTransferProgress(
        transferId: chunk.transferId,
        fileName: session.metadata.fileName,
        progress: progress,
        bytesTransferred: session.receivedChunks!.length * chunkSize,
        totalBytes: session.metadata.fileSize,
        speed: _calculateSpeed(session),
        isComplete: chunk.isLast,
      ));

      // Se é último chunk, verificar hash do arquivo completo
      if (chunk.isLast) {
        await randomAccess.close();
        final fileHash = await _calculateFileHash(file);
        
        if (fileHash != session.metadata.fileHash) {
          DebugUtils.logError('File hash mismatch!');
          await file.delete();
          return false;
        }

        DebugUtils.log('File received successfully: ${session.metadata.fileName}', tag: 'FILE');
      }

      return true;
    } finally {
      await randomAccess.close();
    }
  }

  /// Obter chunks faltantes (para resumir transferência)
  List<int> getMissingChunks(String transferId) {
    final session = _activeSessions[transferId];
    if (session == null) return [];

    final missing = <int>[];
    for (int i = 0; i < session.metadata.totalChunks; i++) {
      if (!session.receivedChunks!.contains(i)) {
        missing.add(i);
      }
    }

    return missing;
  }

  /// Cancelar transferência
  Future<void> cancelTransfer(String transferId) async {
    final session = _activeSessions.remove(transferId);
    
    if (session?.direction == TransferDirection.receiving) {
      final file = File(session!.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    DebugUtils.log('Transfer cancelled: $transferId', tag: 'FILE');
  }

  /// Pausar transferência
  void pauseTransfer(String transferId) {
    final session = _activeSessions[transferId];
    if (session != null) {
      session.isPaused = true;
      DebugUtils.log('Transfer paused: $transferId', tag: 'FILE');
    }
  }

  /// Resumir transferência
  void resumeTransfer(String transferId) {
    final session = _activeSessions[transferId];
    if (session != null) {
      session.isPaused = false;
      session.resumeTime = DateTime.now();
      DebugUtils.log('Transfer resumed: $transferId', tag: 'FILE');
    }
  }

  String _generateTransferId() {
    return 'transfer_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  String _getMimeType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    const mimeTypes = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.mp4': 'video/mp4',
      '.mov': 'video/quicktime',
      '.avi': 'video/x-msvideo',
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.zip': 'application/zip',
      '.rar': 'application/x-rar-compressed',
      '.mp3': 'audio/mpeg',
      '.wav': 'audio/wav',
    };
    
    return mimeTypes[ext] ?? 'application/octet-stream';
  }

  Future<String> _calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  double _calculateSpeed(FileTransferSession session) {
    if (session.startTime == null) return 0.0;
    
    final elapsed = DateTime.now().difference(session.resumeTime ?? session.startTime!);
    if (elapsed.inSeconds == 0) return 0.0;
    
    final bytesTransferred = session.receivedChunks!.length * chunkSize;
    return bytesTransferred / elapsed.inSeconds; // bytes/sec
  }

  void dispose() {
    _activeSessions.clear();
    _progressController.close();
  }
}

class FileMetadata {
  final String transferId;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final String fileHash;
  final String mimeType;

  FileMetadata({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.fileHash,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() => {
    'transfer_id': transferId,
    'file_name': fileName,
    'file_size': fileSize,
    'total_chunks': totalChunks,
    'file_hash': fileHash,
    'mime_type': mimeType,
  };

  factory FileMetadata.fromJson(Map<String, dynamic> json) => FileMetadata(
    transferId: json['transfer_id'],
    fileName: json['file_name'],
    fileSize: json['file_size'],
    totalChunks: json['total_chunks'],
    fileHash: json['file_hash'],
    mimeType: json['mime_type'],
  );
}

class FileChunk {
  final String transferId;
  final int chunkIndex;
  final Uint8List data;
  final String chunkHash;
  final bool isLast;

  FileChunk({
    required this.transferId,
    required this.chunkIndex,
    required this.data,
    required this.chunkHash,
    required this.isLast,
  });
}

class FileTransferProgress {
  final String transferId;
  final String fileName;
  final double progress;
  final int bytesTransferred;
  final int totalBytes;
  final double speed; // bytes/sec
  final bool isComplete;

  FileTransferProgress({
    required this.transferId,
    required this.fileName,
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.speed,
    required this.isComplete,
  });

  int get percentage => (progress * 100).round();
  
  String get speedFormatted {
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(2)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  String get eta {
    if (speed == 0) return '--:--';
    final remaining = totalBytes - bytesTransferred;
    final seconds = (remaining / speed).round();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

enum TransferDirection { sending, receiving }

class FileTransferSession {
  final FileMetadata metadata;
  final String filePath;
  final TransferDirection direction;
  final Set<int>? receivedChunks;
  final File? file;
  final DateTime? startTime;
  DateTime? resumeTime;
  bool isPaused;

  FileTransferSession({
    required this.metadata,
    required this.filePath,
    required this.direction,
    this.receivedChunks,
    this.file,
    DateTime? startTime,
    this.resumeTime,
    this.isPaused = false,
  }) : startTime = startTime ?? DateTime.now();
}
