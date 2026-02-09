import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'p2p_service.dart';
import 'crypto_service.dart';

class FileTransferService {
  final P2PService _p2pService;
  final CryptoService _cryptoService;

  FileTransferService({
    required P2PService p2pService,
    required CryptoService cryptoService,
  })  : _p2pService = p2pService,
        _cryptoService = cryptoService;

  static const int chunkSize = 64 * 1024;
  static const int maxFileSize = 1024 * 1024 * 1024;
  static const int maxRetries = 3;

  final Map<String, _FileTransfer> _activeTransfers = {};
  final Map<String, Timer> _timeouts = {};
  final Map<String, int> _retryCount = {};

  final StreamController<FileTransferProgress> _progressController =
      StreamController<FileTransferProgress>.broadcast();

  Stream<FileTransferProgress> get progressStream => _progressController.stream;

  Future<FileTransferResult> sendFile({
    required String filePath,
    required String peerId,
    String? caption,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return FileTransferResult(success: false, error: 'File not found');
      }

      final stat = await file.stat();
      if (stat.size > maxFileSize) {
        return FileTransferResult(
          success: false,
          error: 'File too large (max ${maxFileSize ~/ (1024 * 1024)}MB)',
        );
      }

      final metadata = await prepareFileForSending(file);
      final metadataJson = jsonEncode(metadata.toJson());

      await _p2pService.sendMessage(peerId: peerId, message: metadataJson);

      await _sendChunks(metadata.transferId, peerId);

      return FileTransferResult(
        success: true,
        messageId: metadata.transferId,
        fileName: metadata.filename,
        fileSize: stat.size,
        fileType: _getFileType(metadata.filename),
      );
    } catch (e) {
      return FileTransferResult(success: false, error: e.toString());
    }
  }

  Future<FileTransferMetadata> prepareFileForSending(File file) async {
    final stat = await file.stat();

    if (stat.size > maxFileSize) {
      throw Exception('File too large');
    }

    final transferId = _generateTransferId();
    final filename = path.basename(file.path);
    final totalChunks = (stat.size / chunkSize).ceil();
    final checksum = await _calculateChecksum(file);

    final metadata = FileTransferMetadata(
      transferId: transferId,
      filename: filename,
      fileSize: stat.size,
      totalChunks: totalChunks,
      chunkSize: chunkSize,
      mimeType: _getMimeType(filename),
      checksum: checksum,
    );

    _activeTransfers[transferId] = _FileTransfer(
      metadata: metadata,
      filePath: file.path,
      direction: TransferDirection.sending,
      startTime: DateTime.now(),
    );

    return metadata;
  }

  Future<void> _sendChunks(String transferId, String peerId) async {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) return;

    for (int i = 0; i < transfer.metadata.totalChunks; i++) {
      final chunk = await getChunk(transferId, i);
      final encrypted = await _cryptoService.encryptBytes(
        chunk.data,
        _cryptoService.getSessionKey(peerId)!,
      );

      final chunkJson = jsonEncode({
        'transfer_id': transferId,
        'chunk_index': i,
        'data': base64Encode(encrypted['ciphertext'] as Uint8List),
        'is_last': i == transfer.metadata.totalChunks - 1,
      });

      await _p2pService.sendMessage(peerId: peerId, message: chunkJson);

      _emitProgress(transferId, i + 1);
    }
  }

  Future<FileChunk> getChunk(String transferId, int chunkIndex) async {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) throw Exception('Transfer not found');

    final file = File(transfer.filePath!);
    final offset = chunkIndex * chunkSize;
    final randomAccess = await file.open(mode: FileMode.read);

    try {
      await randomAccess.setPosition(offset);
      final remaining = transfer.metadata.fileSize - offset;
      final length = remaining < chunkSize ? remaining : chunkSize;
      final data = await randomAccess.read(length);

      return FileChunk(
        transferId: transferId,
        chunkIndex: chunkIndex,
        data: data,
        isLastChunk: chunkIndex == transfer.metadata.totalChunks - 1,
      );
    } finally {
      await randomAccess.close();
    }
  }

  Future<String> startReceiving(FileTransferMetadata metadata) async {
    final directory = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${directory.path}/downloads');

    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final filePath = path.join(downloadsDir.path, metadata.filename);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }

    await file.create();

    _activeTransfers[metadata.transferId] = _FileTransfer(
      metadata: metadata,
      filePath: filePath,
      direction: TransferDirection.receiving,
      receivedChunks: {},
      startTime: DateTime.now(),
    );

    _startTimeout(metadata.transferId);

    return filePath;
  }

  Future<void> processChunk(FileChunk chunk, String peerId) async {
    final transfer = _activeTransfers[chunk.transferId];
    if (transfer == null) throw Exception('Transfer not found');

    if (transfer.receivedChunks!.contains(chunk.chunkIndex)) {
      return;
    }

    final decrypted = await _cryptoService.decryptBytes(
      {
        'ciphertext': chunk.data,
        'nonce': [],
        'mac': [],
      },
      _cryptoService.getSessionKey(peerId)!,
    );

    final file = File(transfer.filePath!);
    final randomAccess = await file.open(mode: FileMode.writeOnlyAppend);

    try {
      final offset = chunk.chunkIndex * chunkSize;
      await randomAccess.setPosition(offset);
      await randomAccess.writeFrom(decrypted);

      transfer.receivedChunks!.add(chunk.chunkIndex);

      _emitProgress(chunk.transferId, transfer.receivedChunks!.length);

      if (chunk.isLastChunk) {
        await _finalizeTransfer(chunk.transferId);
      }
    } finally {
      await randomAccess.close();
    }

    _resetTimeout(chunk.transferId);
  }

  Future<void> _finalizeTransfer(String transferId) async {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) return;

    final file = File(transfer.filePath!);
    final checksum = await _calculateChecksum(file);

    if (checksum == transfer.metadata.checksum) {
      _activeTransfers.remove(transferId);
      _timeouts[transferId]?.cancel();
      _timeouts.remove(transferId);
    } else {
      await _retryTransfer(transferId);
    }
  }

  Future<void> _retryTransfer(String transferId) async {
    final count = _retryCount[transferId] ?? 0;
    if (count < maxRetries) {
      _retryCount[transferId] = count + 1;
      final missing = getMissingChunks(transferId);
      // Request missing chunks
    } else {
      await cancelTransfer(transferId);
    }
  }

  List<int> getMissingChunks(String transferId) {
    final transfer = _activeTransfers[transferId];
    if (transfer == null || transfer.receivedChunks == null) return [];

    final missing = <int>[];
    for (int i = 0; i < transfer.metadata.totalChunks; i++) {
      if (!transfer.receivedChunks!.contains(i)) {
        missing.add(i);
      }
    }

    return missing;
  }

  Future<void> cancelTransfer(String transferId) async {
    final transfer = _activeTransfers.remove(transferId);

    if (transfer != null && transfer.direction == TransferDirection.receiving) {
      final file = File(transfer.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _timeouts[transferId]?.cancel();
    _timeouts.remove(transferId);
    _retryCount.remove(transferId);
  }

  Future<String> _calculateChecksum(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  void _emitProgress(String transferId, int chunksCompleted) {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) return;

    final progress = chunksCompleted / transfer.metadata.totalChunks;
    final bytesTransferred = chunksCompleted * chunkSize;

    _progressController.add(FileTransferProgress(
      transferId: transferId,
      filename: transfer.metadata.filename,
      progress: progress,
      bytesTransferred: bytesTransferred.clamp(0, transfer.metadata.fileSize),
      totalBytes: transfer.metadata.fileSize,
      isComplete: progress >= 1.0,
      speed: _calculateSpeed(transfer),
    ));
  }

  double _calculateSpeed(_FileTransfer transfer) {
    final elapsed = DateTime.now().difference(transfer.startTime).inSeconds;
    if (elapsed == 0) return 0;
    final received = transfer.receivedChunks?.length ?? 0;
    return (received * chunkSize) / elapsed;
  }

  void _startTimeout(String transferId) {
    _timeouts[transferId] = Timer(const Duration(minutes: 5), () {
      cancelTransfer(transferId);
    });
  }

  void _resetTimeout(String transferId) {
    _timeouts[transferId]?.cancel();
    _startTimeout(transferId);
  }

  String _generateTransferId() {
    return 'transfer_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _getMimeType(String filename) {
    final ext = path.extension(filename).toLowerCase();

    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.mp4':
        return 'video/mp4';
      case '.pdf':
        return 'application/pdf';
      case '.zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  String _getFileType(String filename) {
    final mime = _getMimeType(filename);
    if (mime.startsWith('image/')) return 'image';
    if (mime.startsWith('video/')) return 'video';
    if (mime.startsWith('audio/')) return 'audio';
    return 'file';
  }

  void cleanupCompletedTransfers() {
    _activeTransfers.removeWhere((id, transfer) {
      return transfer.direction == TransferDirection.sending ||
          (transfer.receivedChunks?.length ?? 0) == transfer.metadata.totalChunks;
    });
  }

  void dispose() {
    _activeTransfers.clear();
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    _timeouts.clear();
    _progressController.close();
  }
}

class FileTransferMetadata {
  final String transferId;
  final String filename;
  final int fileSize;
  final int totalChunks;
  final int chunkSize;
  final String mimeType;
  final String checksum;

  FileTransferMetadata({
    required this.transferId,
    required this.filename,
    required this.fileSize,
    required this.totalChunks,
    required this.chunkSize,
    required this.mimeType,
    required this.checksum,
  });

  Map<String, dynamic> toJson() {
    return {
      'transfer_id': transferId,
      'filename': filename,
      'file_size': fileSize,
      'total_chunks': totalChunks,
      'chunk_size': chunkSize,
      'mime_type': mimeType,
      'checksum': checksum,
    };
  }

  factory FileTransferMetadata.fromJson(Map<String, dynamic> json) {
    return FileTransferMetadata(
      transferId: json['transfer_id'] as String,
      filename: json['filename'] as String,
      fileSize: json['file_size'] as int,
      totalChunks: json['total_chunks'] as int,
      chunkSize: json['chunk_size'] as int,
      mimeType: json['mime_type'] as String,
      checksum: json['checksum'] as String,
    );
  }
}

class FileChunk {
  final String transferId;
  final int chunkIndex;
  final Uint8List data;
  final bool isLastChunk;

  FileChunk({
    required this.transferId,
    required this.chunkIndex,
    required this.data,
    this.isLastChunk = false,
  });
}

class FileTransferProgress {
  final String transferId;
  final String filename;
  final double progress;
  final int bytesTransferred;
  final int totalBytes;
  final bool isComplete;
  final double speed;

  FileTransferProgress({
    required this.transferId,
    required this.filename,
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.isComplete,
    this.speed = 0,
  });

  int get percentage => (progress * 100).round();

  String get speedText {
    if (speed < 1024) return '${speed.toStringAsFixed(1)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}

class FileTransferResult {
  final bool success;
  final String? messageId;
  final String? fileName;
  final int? fileSize;
  final String? fileType;
  final String? error;

  FileTransferResult({
    required this.success,
    this.messageId,
    this.fileName,
    this.fileSize,
    this.fileType,
    this.error,
  });
}

enum TransferDirection { sending, receiving }

class _FileTransfer {
  final FileTransferMetadata metadata;
  final String? filePath;
  final TransferDirection direction;
  final Set<int>? receivedChunks;
  final DateTime startTime;

  _FileTransfer({
    required this.metadata,
    this.filePath,
    required this.direction,
    this.receivedChunks,
    required this.startTime,
  });
}