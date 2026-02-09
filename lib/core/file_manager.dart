import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:image/image.dart' as img;
import '../core/logger_service.dart';
import '../core/cache_service.dart';

/// Ultra-Optimized File Manager
/// Features:
/// - Smart caching
/// - Auto-compression
/// - Thumbnail generation
/// - File deduplication
/// - Automatic cleanup
/// - Progress tracking
/// - Memory-efficient chunking
class FileManager {
  static final FileManager _instance = FileManager._internal();
  factory FileManager() => _instance;
  FileManager._internal();

  final CacheService _cache = CacheService();
  
  Directory? _appDir;
  Directory? _cacheDir;
  Directory? _filesDir;
  Directory? _thumbnailsDir;
  
  final Map<String, StreamController<FileProgress>> _progressControllers = {};
  
  // Configuration
  static const int thumbnailSize = 200;
  static const int imageQuality = 85;
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const Duration cacheExpiry = Duration(days: 7);
  
  // Stats
  int _totalFilesStored = 0;
  int _totalBytesStored = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Initialize file manager
  Future<void> initialize() async {
    LoggerService.info('FileManager: Initializing');
    
    _appDir = await getApplicationDocumentsDirectory();
    _cacheDir = await getTemporaryDirectory();
    
    _filesDir = Directory(path.join(_appDir!.path, 'files'));
    _thumbnailsDir = Directory(path.join(_appDir!.path, 'thumbnails'));
    
    await _filesDir!.create(recursive: true);
    await _thumbnailsDir!.create(recursive: true);
    
    // Clean old cache on startup
    await _cleanOldCache();
    
    LoggerService.success('FileManager: Initialized');
  }

  /// Save file with automatic optimization
  Future<FileSaveResult> saveFile({
    required File file,
    String? customName,
    bool compress = true,
    bool generateThumbnail = false,
    Function(FileProgress)? onProgress,
  }) async {
    try {
      final fileName = customName ?? path.basename(file.path);
      final fileExt = path.extension(fileName).toLowerCase();
      final fileHash = await _calculateFileHash(file);
      
      // Check for duplicate
      final existing = await _findDuplicateFile(fileHash);
      if (existing != null) {
        LoggerService.info('Duplicate file found: $fileName');
        return FileSaveResult(
          success: true,
          filePath: existing,
          isDuplicate: true,
          originalSize: await file.length(),
          savedSize: await File(existing).length(),
        );
      }

      final savedPath = path.join(_filesDir!.path, fileName);
      File savedFile;
      int originalSize = await file.length();
      int savedSize = originalSize;

      // Auto-compress images
      if (compress && _isImage(fileExt)) {
        savedFile = await _compressImage(
          file,
          savedPath,
          onProgress: onProgress,
        );
        savedSize = await savedFile.length();
        
        LoggerService.info(
          'Compressed image: ${originalSize ~/ 1024}KB → ${savedSize ~/ 1024}KB '
          '(${((1 - savedSize / originalSize) * 100).toStringAsFixed(1)}% saved)',
        );
      } else {
        // Copy file
        savedFile = await _copyFile(file, savedPath, onProgress: onProgress);
      }

      // Generate thumbnail if needed
      String? thumbnailPath;
      if (generateThumbnail && _isImage(fileExt)) {
        thumbnailPath = await _generateThumbnail(savedFile);
      }

      // Cache file info
      _cache.set(
        'file:$fileHash',
        savedFile.path,
        ttl: cacheExpiry,
      );

      _totalFilesStored++;
      _totalBytesStored += savedSize;

      return FileSaveResult(
        success: true,
        filePath: savedFile.path,
        thumbnailPath: thumbnailPath,
        originalSize: originalSize,
        savedSize: savedSize,
        hash: fileHash,
      );
    } catch (e) {
      LoggerService.error('Failed to save file', error: e);
      return FileSaveResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Compress image
  Future<File> _compressImage(
    File file,
    String savePath, {
    Function(FileProgress)? onProgress,
  }) async {
    onProgress?.call(FileProgress(phase: 'Compressing', progress: 0.0));
    
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    onProgress?.call(FileProgress(phase: 'Compressing', progress: 0.5));

    // Resize if too large (max 2048px)
    img.Image resized = image;
    if (image.width > 2048 || image.height > 2048) {
      resized = img.copyResize(
        image,
        width: image.width > image.height ? 2048 : null,
        height: image.height > image.width ? 2048 : null,
      );
    }

    // Encode as JPEG with quality
    final compressed = img.encodeJpg(resized, quality: imageQuality);
    
    onProgress?.call(FileProgress(phase: 'Saving', progress: 0.9));
    
    final savedFile = File(savePath);
    await savedFile.writeAsBytes(compressed);
    
    onProgress?.call(FileProgress(phase: 'Complete', progress: 1.0));
    
    return savedFile;
  }

  /// Generate thumbnail
  Future<String> _generateThumbnail(File file) async {
    final fileName = path.basename(file.path);
    final thumbPath = path.join(_thumbnailsDir!.path, 'thumb_$fileName');
    
    // Check cache
    final cached = _cache.get<String>('thumb:$fileName');
    if (cached != null && await File(cached).exists()) {
      _cacheHits++;
      return cached;
    }
    _cacheMisses++;

    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Create thumbnail
    final thumbnail = img.copyResize(
      image,
      width: thumbnailSize,
      height: thumbnailSize,
    );

    final thumbBytes = img.encodeJpg(thumbnail, quality: 80);
    await File(thumbPath).writeAsBytes(thumbBytes);
    
    // Cache thumbnail path
    _cache.set('thumb:$fileName', thumbPath, ttl: cacheExpiry);
    
    LoggerService.debug('Generated thumbnail: $fileName');
    
    return thumbPath;
  }

  /// Copy file with progress
  Future<File> _copyFile(
    File source,
    String destPath, {
    Function(FileProgress)? onProgress,
  }) async {
    final dest = File(destPath);
    final fileSize = await source.length();
    
    if (fileSize < 1024 * 1024) {
      // Small file, copy directly
      await source.copy(destPath);
      onProgress?.call(FileProgress(phase: 'Complete', progress: 1.0));
      return dest;
    }

    // Large file, copy with progress
    final sourceStream = source.openRead();
    final destSink = dest.openWrite();
    
    int bytesCopied = 0;
    
    await for (final chunk in sourceStream) {
      destSink.add(chunk);
      bytesCopied += chunk.length;
      
      onProgress?.call(FileProgress(
        phase: 'Copying',
        progress: bytesCopied / fileSize,
        bytesTransferred: bytesCopied,
        totalBytes: fileSize,
      ));
    }
    
    await destSink.close();
    
    onProgress?.call(FileProgress(phase: 'Complete', progress: 1.0));
    
    return dest;
  }

  /// Calculate file hash
  Future<String> _calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Find duplicate file
  Future<String?> _findDuplicateFile(String hash) async {
    return _cache.get<String>('file:$hash');
  }

  /// Clean old cache
  Future<void> _cleanOldCache() async {
    LoggerService.info('Cleaning old cache...');
    
    int filesDeleted = 0;
    int bytesFreed = 0;

    // Clean old files
    final files = await _filesDir!.list().toList();
    for (final file in files) {
      if (file is File) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        
        if (age > cacheExpiry) {
          bytesFreed += stat.size;
          await file.delete();
          filesDeleted++;
        }
      }
    }

    // Clean old thumbnails
    final thumbs = await _thumbnailsDir!.list().toList();
    for (final thumb in thumbs) {
      if (thumb is File) {
        final stat = await thumb.stat();
        final age = DateTime.now().difference(stat.modified);
        
        if (age > cacheExpiry) {
          await thumb.delete();
        }
      }
    }

    if (filesDeleted > 0) {
      LoggerService.success(
        'Cleaned $filesDeleted files, freed ${bytesFreed ~/ (1024 * 1024)}MB',
      );
    }
  }

  /// Get file by path
  Future<File?> getFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Delete file
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        _totalFilesStored--;
        LoggerService.info('Deleted file: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      LoggerService.error('Failed to delete file', error: e);
      return false;
    }
  }

  /// Check if file is image
  bool _isImage(String extension) {
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp']
        .contains(extension);
  }

  /// Get statistics
  FileManagerStats getStats() {
    return FileManagerStats(
      totalFiles: _totalFilesStored,
      totalBytes: _totalBytesStored,
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
    );
  }

  /// Dispose
  void dispose() {
    _progressControllers.forEach((key, controller) {
      controller.close();
    });
    _progressControllers.clear();
  }
}

class FileSaveResult {
  final bool success;
  final String? filePath;
  final String? thumbnailPath;
  final int? originalSize;
  final int? savedSize;
  final String? hash;
  final bool isDuplicate;
  final String? error;

  FileSaveResult({
    required this.success,
    this.filePath,
    this.thumbnailPath,
    this.originalSize,
    this.savedSize,
    this.hash,
    this.isDuplicate = false,
    this.error,
  });

  double? get compressionRatio {
    if (originalSize == null || savedSize == null) return null;
    return 1 - (savedSize! / originalSize!);
  }

  int? get bytesSaved {
    if (originalSize == null || savedSize == null) return null;
    return originalSize! - savedSize!;
  }
}

class FileProgress {
  final String phase;
  final double progress;
  final int? bytesTransferred;
  final int? totalBytes;

  FileProgress({
    required this.phase,
    required this.progress,
    this.bytesTransferred,
    this.totalBytes,
  });
}

class FileManagerStats {
  final int totalFiles;
  final int totalBytes;
  final int cacheHits;
  final int cacheMisses;

  FileManagerStats({
    required this.totalFiles,
    required this.totalBytes,
    required this.cacheHits,
    required this.cacheMisses,
  });

  double get cacheHitRate {
    final total = cacheHits + cacheMisses;
    if (total == 0) return 0;
    return cacheHits / total;
  }

  String get totalSizeFormatted {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${totalBytes ~/ 1024} KB';
    return '${totalBytes ~/ (1024 * 1024)} MB';
  }
}
