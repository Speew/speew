import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../core/utils.dart';

/// Serviço de transferência de arquivos grandes com chunking
/// Suporta arquivos de até 1GB com resumo automático
class FileTransferService {
  static const int chunkSize = 64 * 1024; // 64KB por chunk
  static const int maxFileSize = 1024 * 1024 * 1024; // 1GB
  
  // Transferências ativas
  final Map<String, _FileTransfer> _activeTransfers = {};
  
  // Callbacks
  final StreamController<FileTransferProgress> _progressController =
      StreamController<FileTransferProgress>.broadcast();
  
  Stream<FileTransferProgress> get progressStream => _progressController.stream;

  /// Preparar arquivo para envio (fragmentar)
  Future<FileTransferMetadata> prepareFileForSending(File file) async {
    final stat = await file.stat();
    
    if (stat.size > maxFileSize) {
      throw Exception('File too large (max ${maxFileSize ~/ (1024 * 1024)}MB)');
    }

    final transferId = _generateTransferId();
    final filename = path.basename(file.path);
    final totalChunks = (stat.size / chunkSize).ceil();

    final metadata = FileTransferMetadata(
      transferId: transferId,
      filename: filename,
      fileSize: stat.size,
      totalChunks: totalChunks,
      chunkSize: chunkSize,
      mimeType: _getMimeType(filename),
    );

    _activeTransfers[transferId] = _FileTransfer(
      metadata: metadata,
      filePath: file.path,
      direction: TransferDirection.sending,
    );

    DebugUtils.log(
      'File prepared: $filename (${stat.size} bytes, $totalChunks chunks)',
      tag: 'FILE',
    );

    return metadata;
  }

  /// Obter chunk específico do arquivo
  Future<FileChunk> getChunk(String transferId, int chunkIndex) async {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) {
      throw Exception('Transfer not found: $transferId');
    }

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

  /// Iniciar recepção de arquivo
  Future<String> startReceiving(FileTransferMetadata metadata) async {
    final directory = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${directory.path}/downloads');
    
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final filePath = path.join(downloadsDir.path, metadata.filename);
    final file = File(filePath);

    _activeTransfers[metadata.transferId] = _FileTransfer(
      metadata: metadata,
      filePath: filePath,
      direction: TransferDirection.receiving,
      receivedChunks: {},
    );

    DebugUtils.log('Receiving: ${metadata.filename}', tag: 'FILE');

    return filePath;
  }

  /// Processar chunk recebido
  Future<void> processChunk(FileChunk chunk) async {
    final transfer = _activeTransfers[chunk.transferId];
    if (transfer == null) {
      throw Exception('Transfer not found: ${chunk.transferId}');
    }

    final file = File(transfer.filePath!);
    final randomAccess = await file.open(mode: FileMode.writeOnlyAppend);
    
    try {
      final offset = chunk.chunkIndex * chunkSize;
      await randomAccess.setPosition(offset);
      await randomAccess.writeFrom(chunk.data);
      
      transfer.receivedChunks!.add(chunk.chunkIndex);
      
      // Calcular progresso
      final progress = transfer.receivedChunks!.length / 
                      transfer.metadata.totalChunks;

      _progressController.add(FileTransferProgress(
        transferId: chunk.transferId,
        filename: transfer.metadata.filename,
        progress: progress,
        bytesTransferred: transfer.receivedChunks!.length * chunkSize,
        totalBytes: transfer.metadata.fileSize,
        isComplete: chunk.isLastChunk,
      ));

      if (chunk.isLastChunk) {
        DebugUtils.log(
          'File received: ${transfer.metadata.filename}',
          tag: 'FILE',
        );
      }
    } finally {
      await randomAccess.close();
    }
  }

  /// Obter chunks faltantes (para resumo)
  List<int> getMissingChunks(String transferId) {
    final transfer = _activeTransfers[transferId];
    if (transfer == null || transfer.receivedChunks == null) {
      return [];
    }

    final missing = <int>[];
    for (int i = 0; i < transfer.metadata.totalChunks; i++) {
      if (!transfer.receivedChunks!.contains(i)) {
        missing.add(i);
      }
    }

    return missing;
  }

  /// Cancelar transferência
  Future<void> cancelTransfer(String transferId) async {
    final transfer = _activeTransfers.remove(transferId);
    
    if (transfer != null && 
        transfer.direction == TransferDirection.receiving) {
      // Deletar arquivo parcial
      final file = File(transfer.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    DebugUtils.log('Transfer cancelled: $transferId', tag: 'FILE');
  }

  /// Verificar integridade do arquivo (SHA-256)
  Future<String> calculateChecksum(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    
    // TODO: Implementar SHA-256
    // Por enquanto, retorna hash simples
    return bytes.length.toString();
  }

  /// Limpar transferências concluídas
  void cleanupCompletedTransfers() {
    _activeTransfers.removeWhere((id, transfer) {
      return transfer.direction == TransferDirection.sending ||
             (transfer.receivedChunks?.length ?? 0) == 
             transfer.metadata.totalChunks;
    });
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

  void dispose() {
    _activeTransfers.clear();
    _progressController.close();
  }
}

/// Metadata da transferência de arquivo
class FileTransferMetadata {
  final String transferId;
  final String filename;
  final int fileSize;
  final int totalChunks;
  final int chunkSize;
  final String mimeType;

  FileTransferMetadata({
    required this.transferId,
    required this.filename,
    required this.fileSize,
    required this.totalChunks,
    required this.chunkSize,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() {
    return {
      'transfer_id': transferId,
      'filename': filename,
      'file_size': fileSize,
      'total_chunks': totalChunks,
      'chunk_size': chunkSize,
      'mime_type': mimeType,
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
    );
  }
}

/// Chunk de arquivo
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

  Map<String, dynamic> toJson() {
    return {
      'transfer_id': transferId,
      'chunk_index': chunkIndex,
      'data': data,
      'is_last_chunk': isLastChunk,
    };
  }
}

/// Progresso de transferência
class FileTransferProgress {
  final String transferId;
  final String filename;
  final double progress; // 0.0 - 1.0
  final int bytesTransferred;
  final int totalBytes;
  final bool isComplete;

  FileTransferProgress({
    required this.transferId,
    required this.filename,
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.isComplete,
  });

  int get percentage => (progress * 100).round();
  
  String get speedText {
    // TODO: Calcular velocidade real
    return '${(bytesTransferred / 1024).toStringAsFixed(1)} KB';
  }
}

enum TransferDirection { sending, receiving }

class _FileTransfer {
  final FileTransferMetadata metadata;
  final String? filePath;
  final TransferDirection direction;
  final Set<int>? receivedChunks;

  _FileTransfer({
    required this.metadata,
    this.filePath,
    required this.direction,
    this.receivedChunks,
  });
}
