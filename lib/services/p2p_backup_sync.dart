import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../core/utils.dart';

/// P2P Backup & Sync - Backup sem servidor
/// Features:
/// - Backup encrypted
/// - Multi-device sync
/// - Incremental backup
/// - Conflict resolution
/// - Version history
/// - Peer-to-peer replication
class P2PBackupSync {
  final Map<String, BackupSession> _activeSessions = {};
  final Map<String, SyncState> _syncStates = {};
  
  final StreamController<BackupEvent> _eventController =
      StreamController<BackupEvent>.broadcast();

  Stream<BackupEvent> get eventStream => _eventController.stream;

  /// Criar backup completo
  Future<BackupMetadata> createFullBackup({
    required List<String> includePaths,
    bool encrypt = true,
    String? targetPeerId,
  }) async {
    final backupId = _generateBackupId();
    final timestamp = DateTime.now();

    DebugUtils.log('Creating full backup: $backupId', tag: 'BACKUP');

    // Coletar arquivos
    final files = await _collectFiles(includePaths);
    
    // Calcular hash de cada arquivo
    final fileHashes = <String, String>{};
    for (final file in files) {
      final hash = await _calculateFileHash(File(file));
      fileHashes[file] = hash;
    }

    // Criar manifest
    final metadata = BackupMetadata(
      backupId: backupId,
      timestamp: timestamp,
      type: BackupType.full,
      files: fileHashes,
      totalSize: await _calculateTotalSize(files),
      encrypted: encrypt,
    );

    // Salvar manifest
    await _saveBackupManifest(metadata);

    // Iniciar sessão de backup
    final session = BackupSession(
      metadata: metadata,
      targetPeerId: targetPeerId,
      status: BackupStatus.inProgress,
    );

    _activeSessions[backupId] = session;

    // Backup em background
    _performBackup(session, files, encrypt);

    return metadata;
  }

  /// Criar backup incremental
  Future<BackupMetadata> createIncrementalBackup({
    required String baseBackupId,
    required List<String> includePaths,
    bool encrypt = true,
    String? targetPeerId,
  }) async {
    final backupId = _generateBackupId();
    final timestamp = DateTime.now();

    DebugUtils.log('Creating incremental backup: $backupId', tag: 'BACKUP');

    // Obter backup base
    final baseBackup = await _loadBackupManifest(baseBackupId);
    if (baseBackup == null) {
      throw Exception('Base backup not found');
    }

    // Coletar arquivos atuais
    final currentFiles = await _collectFiles(includePaths);
    
    // Detectar mudanças
    final changes = await _detectChanges(baseBackup.files, currentFiles);

    // Criar manifest incremental
    final metadata = BackupMetadata(
      backupId: backupId,
      timestamp: timestamp,
      type: BackupType.incremental,
      baseBackupId: baseBackupId,
      files: changes.modified,
      deletedFiles: changes.deleted,
      totalSize: await _calculateTotalSize(changes.modified.keys.toList()),
      encrypted: encrypt,
    );

    await _saveBackupManifest(metadata);

    final session = BackupSession(
      metadata: metadata,
      targetPeerId: targetPeerId,
      status: BackupStatus.inProgress,
    );

    _activeSessions[backupId] = session;

    _performBackup(session, changes.modified.keys.toList(), encrypt);

    return metadata;
  }

  /// Sincronizar com peer
  Future<void> syncWithPeer(String peerId) async {
    DebugUtils.log('Starting sync with $peerId', tag: 'SYNC');

    // Obter estado de sync do peer
    final peerState = await _requestSyncState(peerId);
    final localState = await _getLocalSyncState();

    // Comparar e resolver diferenças
    final diff = _compareSyncStates(localState, peerState);

    // Enviar arquivos que peer não tem
    for (final file in diff.filesToSend) {
      await _sendFile(peerId, file);
    }

    // Receber arquivos que não temos
    for (final file in diff.filesToReceive) {
      await _requestFile(peerId, file);
    }

    // Resolver conflitos
    for (final conflict in diff.conflicts) {
      await _resolveConflict(conflict, peerId);
    }

    DebugUtils.log('Sync completed with $peerId', tag: 'SYNC');
  }

  /// Restaurar backup
  Future<void> restoreBackup({
    required String backupId,
    required String targetPath,
    String? sourcePeerId,
  }) async {
    DebugUtils.log('Restoring backup: $backupId', tag: 'BACKUP');

    // Carregar manifest
    final metadata = await _loadBackupManifest(backupId);
    if (metadata == null) {
      throw Exception('Backup not found');
    }

    // Se é incremental, restaurar base primeiro
    if (metadata.type == BackupType.incremental && metadata.baseBackupId != null) {
      await restoreBackup(
        backupId: metadata.baseBackupId!,
        targetPath: targetPath,
        sourcePeerId: sourcePeerId,
      );
    }

    // Restaurar arquivos
    for (final filePath in metadata.files.keys) {
      final fileHash = metadata.files[filePath]!;
      
      // Buscar arquivo
      final fileData = await _findFileByHash(fileHash, sourcePeerId);
      
      if (fileData != null) {
        // Decriptar se necessário
        var data = fileData;
        if (metadata.encrypted) {
          data = await _decryptData(data);
        }

        // Salvar arquivo
        final targetFile = File('$targetPath/$filePath');
        await targetFile.create(recursive: true);
        await targetFile.writeAsBytes(data);
      }
    }

    // Deletar arquivos removidos (se incremental)
    if (metadata.deletedFiles != null) {
      for (final filePath in metadata.deletedFiles!) {
        final file = File('$targetPath/$filePath');
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    _eventController.add(BackupEvent(
      type: BackupEventType.restoreCompleted,
      backupId: backupId,
    ));

    DebugUtils.log('Backup restored successfully', tag: 'BACKUP');
  }

  /// Realizar backup em background
  Future<void> _performBackup(
    BackupSession session,
    List<String> files,
    bool encrypt,
  ) async {
    try {
      int processed = 0;

      for (final filePath in files) {
        final file = File(filePath);
        var data = await file.readAsBytes();

        // Encriptar se necessário
        if (encrypt) {
          data = await _encryptData(data);
        }

        // Salvar em storage local
        final fileHash = session.metadata.files[filePath]!;
        await _saveBackupFile(fileHash, data);

        // Se tem target peer, enviar também
        if (session.targetPeerId != null) {
          await _sendFile(session.targetPeerId!, filePath, data);
        }

        processed++;
        final progress = processed / files.length;

        _eventController.add(BackupEvent(
          type: BackupEventType.progress,
          backupId: session.metadata.backupId,
          progress: progress,
        ));
      }

      session.status = BackupStatus.completed;
      session.completedAt = DateTime.now();

      _eventController.add(BackupEvent(
        type: BackupEventType.completed,
        backupId: session.metadata.backupId,
      ));

      DebugUtils.log('Backup completed: ${session.metadata.backupId}', tag: 'BACKUP');
    } catch (e) {
      session.status = BackupStatus.failed;
      session.error = e.toString();

      _eventController.add(BackupEvent(
        type: BackupEventType.failed,
        backupId: session.metadata.backupId,
        error: e.toString(),
      ));

      DebugUtils.logError('Backup failed', error: e);
    }
  }

  /// Detectar mudanças entre backups
  Future<FileChanges> _detectChanges(
    Map<String, String> baseFiles,
    List<String> currentPaths,
  ) async {
    final modified = <String, String>{};
    final deleted = <String>[];

    // Calcular hashes dos arquivos atuais
    final currentFiles = <String, String>{};
    for (final path in currentPaths) {
      final hash = await _calculateFileHash(File(path));
      currentFiles[path] = hash;
    }

    // Detectar modificados e novos
    for (final entry in currentFiles.entries) {
      if (!baseFiles.containsKey(entry.key) || 
          baseFiles[entry.key] != entry.value) {
        modified[entry.key] = entry.value;
      }
    }

    // Detectar deletados
    for (final path in baseFiles.keys) {
      if (!currentFiles.containsKey(path)) {
        deleted.add(path);
      }
    }

    return FileChanges(modified: modified, deleted: deleted);
  }

  /// Resolver conflito de sync
  Future<void> _resolveConflict(
    SyncConflict conflict,
    String peerId,
  ) async {
    // Estratégias de resolução:
    // 1. Last-Write-Wins (LWW)
    // 2. User choice
    // 3. Keep both (rename)

    DebugUtils.log('Resolving conflict: ${conflict.filePath}', tag: 'SYNC');

    // Por padrão: Last-Write-Wins
    if (conflict.localTimestamp.isAfter(conflict.remoteTimestamp)) {
      // Manter versão local, enviar para peer
      await _sendFile(peerId, conflict.filePath);
    } else {
      // Aceitar versão remota
      await _requestFile(peerId, conflict.filePath);
    }
  }

  /// Comparar estados de sync
  SyncDiff _compareSyncStates(SyncState local, SyncState remote) {
    final filesToSend = <String>[];
    final filesToReceive = <String>[];
    final conflicts = <SyncConflict>[];

    // Arquivos para enviar (local tem, remote não)
    for (final entry in local.files.entries) {
      if (!remote.files.containsKey(entry.key)) {
        filesToSend.add(entry.key);
      } else if (remote.files[entry.key]!.hash != entry.value.hash) {
        // Mesmo arquivo, hashes diferentes = conflito
        conflicts.add(SyncConflict(
          filePath: entry.key,
          localHash: entry.value.hash,
          remoteHash: remote.files[entry.key]!.hash,
          localTimestamp: entry.value.modified,
          remoteTimestamp: remote.files[entry.key]!.modified,
        ));
      }
    }

    // Arquivos para receber (remote tem, local não)
    for (final entry in remote.files.entries) {
      if (!local.files.containsKey(entry.key)) {
        filesToReceive.add(entry.key);
      }
    }

    return SyncDiff(
      filesToSend: filesToSend,
      filesToReceive: filesToReceive,
      conflicts: conflicts,
    );
  }

  Future<List<String>> _collectFiles(List<String> paths) async {
    final files = <String>[];

    for (final path in paths) {
      final entity = FileSystemEntity.typeSync(path);

      if (entity == FileSystemEntityType.file) {
        files.add(path);
      } else if (entity == FileSystemEntityType.directory) {
        final dir = Directory(path);
        await for (final file in dir.list(recursive: true)) {
          if (file is File) {
            files.add(file.path);
          }
        }
      }
    }

    return files;
  }

  Future<String> _calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<int> _calculateTotalSize(List<String> files) async {
    int total = 0;
    for (final path in files) {
      final file = File(path);
      final stat = await file.stat();
      total += stat.size;
    }
    return total;
  }

  Future<void> _saveBackupManifest(BackupMetadata metadata) async {
    final dir = await getApplicationDocumentsDirectory();
    final manifestFile = File('${dir.path}/backups/${metadata.backupId}.json');
    
    await manifestFile.create(recursive: true);
    await manifestFile.writeAsString(jsonEncode(metadata.toJson()));
  }

  Future<BackupMetadata?> _loadBackupManifest(String backupId) async {
    final dir = await getApplicationDocumentsDirectory();
    final manifestFile = File('${dir.path}/backups/$backupId.json');
    
    if (!await manifestFile.exists()) return null;
    
    final json = jsonDecode(await manifestFile.readAsString());
    return BackupMetadata.fromJson(json);
  }

  Future<void> _saveBackupFile(String hash, List<int> data) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/backup_data/$hash');
    
    await file.create(recursive: true);
    await file.writeAsBytes(data);
  }

  Future<List<int>?> _findFileByHash(String hash, String? peerId) async {
    // Buscar localmente primeiro
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/backup_data/$hash');
    
    if (await file.exists()) {
      return await file.readAsBytes();
    }

    // Se não encontrar e tem peer, solicitar
    if (peerId != null) {
      return await _requestFileByHash(peerId, hash);
    }

    return null;
  }

  Future<List<int>> _encryptData(List<int> data) async {
    // Implementar encriptação usando E2E service
    return data; // Placeholder
  }

  Future<List<int>> _decryptData(List<int> data) async {
    // Implementar decriptação usando E2E service
    return data; // Placeholder
  }

  // Métodos de comunicação P2P (placeholders)
  Future<SyncState> _requestSyncState(String peerId) async {
    return SyncState(files: {});
  }

  Future<SyncState> _getLocalSyncState() async {
    return SyncState(files: {});
  }

  Future<void> _sendFile(String peerId, String filePath, [List<int>? data]) async {
    // Enviar via P2P
  }

  Future<void> _requestFile(String peerId, String filePath) async {
    // Solicitar via P2P
  }

  Future<List<int>?> _requestFileByHash(String peerId, String hash) async {
    // Solicitar arquivo específico por hash
    return null;
  }

  String _generateBackupId() {
    return 'backup_${DateTime.now().millisecondsSinceEpoch}';
  }

  void dispose() {
    _eventController.close();
  }
}

class BackupMetadata {
  final String backupId;
  final DateTime timestamp;
  final BackupType type;
  final String? baseBackupId;
  final Map<String, String> files; // path -> hash
  final List<String>? deletedFiles;
  final int totalSize;
  final bool encrypted;

  BackupMetadata({
    required this.backupId,
    required this.timestamp,
    required this.type,
    this.baseBackupId,
    required this.files,
    this.deletedFiles,
    required this.totalSize,
    required this.encrypted,
  });

  Map<String, dynamic> toJson() => {
    'backup_id': backupId,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'type': type.toString(),
    'base_backup_id': baseBackupId,
    'files': files,
    'deleted_files': deletedFiles,
    'total_size': totalSize,
    'encrypted': encrypted,
  };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) => BackupMetadata(
    backupId: json['backup_id'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    type: BackupType.values.firstWhere((e) => e.toString() == json['type']),
    baseBackupId: json['base_backup_id'],
    files: Map<String, String>.from(json['files']),
    deletedFiles: json['deleted_files'] != null 
        ? List<String>.from(json['deleted_files'])
        : null,
    totalSize: json['total_size'],
    encrypted: json['encrypted'],
  );
}

enum BackupType { full, incremental }
enum BackupStatus { pending, inProgress, completed, failed }

class BackupSession {
  final BackupMetadata metadata;
  final String? targetPeerId;
  BackupStatus status;
  DateTime? completedAt;
  String? error;

  BackupSession({
    required this.metadata,
    this.targetPeerId,
    required this.status,
    this.completedAt,
    this.error,
  });
}

class BackupEvent {
  final BackupEventType type;
  final String backupId;
  final double? progress;
  final String? error;

  BackupEvent({
    required this.type,
    required this.backupId,
    this.progress,
    this.error,
  });
}

enum BackupEventType { progress, completed, failed, restoreCompleted }

class FileChanges {
  final Map<String, String> modified;
  final List<String> deleted;

  FileChanges({required this.modified, required this.deleted});
}

class SyncState {
  final Map<String, FileMetadata> files;

  SyncState({required this.files});
}

class FileMetadata {
  final String hash;
  final DateTime modified;
  final int size;

  FileMetadata({
    required this.hash,
    required this.modified,
    required this.size,
  });
}

class SyncDiff {
  final List<String> filesToSend;
  final List<String> filesToReceive;
  final List<SyncConflict> conflicts;

  SyncDiff({
    required this.filesToSend,
    required this.filesToReceive,
    required this.conflicts,
  });
}

class SyncConflict {
  final String filePath;
  final String localHash;
  final String remoteHash;
  final DateTime localTimestamp;
  final DateTime remoteTimestamp;

  SyncConflict({
    required this.filePath,
    required this.localHash,
    required this.remoteHash,
    required this.localTimestamp,
    required this.remoteTimestamp,
  });
}
