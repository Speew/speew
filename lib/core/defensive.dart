import 'package:flutter/foundation.dart';
import 'error/error_handler.dart';

/// Defensive - Sistema de validação defensiva para prevenir crashes
/// Valida inputs, estados, e condições antes de operações críticas
class Defensive {
  
  // ==================== STRING VALIDATION ====================
  
  static String requireNonEmpty(String? value, [String fieldName = 'Field']) {
    if (value == null || value.trim().isEmpty) {
      throw ValidationException('$fieldName cannot be empty');
    }
    return value.trim();
  }

  static String? optionalNonEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String limitLength(String value, int maxLength, [String fieldName = 'Field']) {
    if (value.length > maxLength) {
      throw ValidationException('$fieldName exceeds max length of $maxLength');
    }
    return value;
  }

  static String sanitizeString(String? value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    
    // Remove caracteres perigosos
    var sanitized = value
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '')
        .trim();
    
    return sanitized.isEmpty ? defaultValue : sanitized;
  }

  // ==================== NUMBER VALIDATION ====================
  
  static int requirePositive(int? value, [String fieldName = 'Value']) {
    if (value == null || value <= 0) {
      throw ValidationException('$fieldName must be positive');
    }
    return value;
  }

  static int requireNonNegative(int? value, [String fieldName = 'Value']) {
    if (value == null || value < 0) {
      throw ValidationException('$fieldName must be non-negative');
    }
    return value;
  }

  static int requireRange(int? value, int min, int max, [String fieldName = 'Value']) {
    if (value == null) {
      throw ValidationException('$fieldName is null');
    }
    if (value < min || value > max) {
      throw ValidationException('$fieldName must be between $min and $max');
    }
    return value;
  }

  static int clampSafe(int value, int min, int max) {
    return value.clamp(min, max);
  }

  static double requirePositiveDouble(double? value, [String fieldName = 'Value']) {
    if (value == null || value <= 0) {
      throw ValidationException('$fieldName must be positive');
    }
    if (value.isNaN || value.isInfinite) {
      throw ValidationException('$fieldName is invalid (NaN or Infinite)');
    }
    return value;
  }

  // ==================== COLLECTION VALIDATION ====================
  
  static List<T> requireNonEmpty<T>(List<T>? list, [String fieldName = 'List']) {
    if (list == null || list.isEmpty) {
      throw ValidationException('$fieldName cannot be empty');
    }
    return list;
  }

  static List<T> limitSize<T>(List<T> list, int maxSize, [String fieldName = 'List']) {
    if (list.length > maxSize) {
      throw ValidationException('$fieldName exceeds max size of $maxSize');
    }
    return list;
  }

  static T requireElement<T>(List<T>? list, int index, [String fieldName = 'List']) {
    if (list == null || index < 0 || index >= list.length) {
      throw ValidationException('$fieldName does not have element at index $index');
    }
    return list[index];
  }

  static List<T> safeSublist<T>(List<T> list, int start, [int? end]) {
    final safeStart = start.clamp(0, list.length);
    final safeEnd = (end ?? list.length).clamp(safeStart, list.length);
    return list.sublist(safeStart, safeEnd);
  }

  // ==================== MAP VALIDATION ====================
  
  static T requireKey<K, T>(Map<K, T>? map, K key, [String fieldName = 'Key']) {
    if (map == null || !map.containsKey(key)) {
      throw ValidationException('$fieldName "$key" not found in map');
    }
    return map[key]!;
  }

  static T? optionalKey<K, T>(Map<K, T>? map, K key) {
    return map?[key];
  }

  static Map<K, V> requireNonEmptyMap<K, V>(Map<K, V>? map, [String fieldName = 'Map']) {
    if (map == null || map.isEmpty) {
      throw ValidationException('$fieldName cannot be empty');
    }
    return map;
  }

  // ==================== FILE VALIDATION ====================
  
  static void requireFileSize(int fileSize, int maxSize) {
    if (fileSize > maxSize) {
      final maxMB = maxSize / (1024 * 1024);
      final actualMB = fileSize / (1024 * 1024);
      throw ValidationException(
        'File too large: ${actualMB.toStringAsFixed(2)}MB (max: ${maxMB.toStringAsFixed(2)}MB)'
      );
    }
  }

  static void requireValidExtension(String fileName, List<String> allowedExtensions) {
    final ext = fileName.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw ValidationException(
        'Invalid file extension: $ext (allowed: ${allowedExtensions.join(", ")})'
      );
    }
  }

  static String requireValidPath(String? path, [String fieldName = 'Path']) {
    if (path == null || path.isEmpty) {
      throw ValidationException('$fieldName is empty');
    }
    
    // Prevenir path traversal
    if (path.contains('..') || path.contains('~')) {
      throw ValidationException('$fieldName contains invalid characters');
    }
    
    return path;
  }

  // ==================== DATE/TIME VALIDATION ====================
  
  static DateTime requireFutureDate(DateTime? date, [String fieldName = 'Date']) {
    if (date == null) {
      throw ValidationException('$fieldName is null');
    }
    if (date.isBefore(DateTime.now())) {
      throw ValidationException('$fieldName must be in the future');
    }
    return date;
  }

  static DateTime requirePastDate(DateTime? date, [String fieldName = 'Date']) {
    if (date == null) {
      throw ValidationException('$fieldName is null');
    }
    if (date.isAfter(DateTime.now())) {
      throw ValidationException('$fieldName must be in the past');
    }
    return date;
  }

  static Duration requirePositiveDuration(Duration? duration, [String fieldName = 'Duration']) {
    if (duration == null || duration.isNegative) {
      throw ValidationException('$fieldName must be positive');
    }
    return duration;
  }

  // ==================== OBJECT VALIDATION ====================
  
  static T requireNonNull<T>(T? value, [String fieldName = 'Value']) {
    if (value == null) {
      throw ValidationException('$fieldName is null');
    }
    return value;
  }

  static void requireState(bool condition, String message) {
    if (!condition) {
      throw StateException(message);
    }
  }

  static void requireInitialized(bool isInitialized, String serviceName) {
    if (!isInitialized) {
      throw StateException('$serviceName is not initialized');
    }
  }

  // ==================== CRYPTO/SECURITY VALIDATION ====================
  
  static void requireMinLength(String value, int minLength, [String fieldName = 'Value']) {
    if (value.length < minLength) {
      throw ValidationException('$fieldName must be at least $minLength characters');
    }
  }

  static String requireHexString(String? value, [String fieldName = 'Hash']) {
    if (value == null || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
      throw ValidationException('$fieldName is not a valid hex string');
    }
    return value;
  }

  static String requireBase64(String? value, [String fieldName = 'Data']) {
    if (value == null || !RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(value)) {
      throw ValidationException('$fieldName is not valid base64');
    }
    return value;
  }

  // ==================== NETWORK VALIDATION ====================
  
  static String requireValidPeerId(String? peerId) {
    if (peerId == null || peerId.isEmpty) {
      throw ValidationException('Peer ID cannot be empty');
    }
    if (peerId.length > 256) {
      throw ValidationException('Peer ID too long');
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(peerId)) {
      throw ValidationException('Peer ID contains invalid characters');
    }
    return peerId;
  }

  static int requireValidPort(int? port) {
    if (port == null || port < 1 || port > 65535) {
      throw ValidationException('Invalid port number: $port');
    }
    return port;
  }

  // ==================== BATCH VALIDATION ====================
  
  static Map<String, dynamic> validateMessageData(Map<String, dynamic> data) {
    requireKey(data, 'id', 'Message ID');
    requireKey(data, 'senderId', 'Sender ID');
    requireKey(data, 'content', 'Content');
    requireKey(data, 'timestamp', 'Timestamp');
    
    requireNonEmpty(data['id'] as String?, 'Message ID');
    requireNonEmpty(data['senderId'] as String?, 'Sender ID');
    
    return data;
  }

  static Map<String, dynamic> validatePeerData(Map<String, dynamic> data) {
    requireKey(data, 'id', 'Peer ID');
    requireKey(data, 'name', 'Peer Name');
    
    requireValidPeerId(data['id'] as String?);
    requireNonEmpty(data['name'] as String?, 'Peer Name');
    
    return data;
  }

  // ==================== SAFE OPERATIONS ====================
  
  static T? trySafe<T>(T Function() operation, {String? operationName}) {
    try {
      return operation();
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ Safe operation failed${operationName != null ? " ($operationName)" : ""}: $e');
        print(stack);
      }
      return null;
    }
  }

  static Future<T?> tryAsyncSafe<T>(
    Future<T> Function() operation, {
    String? operationName,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      return await operation().timeout(timeout);
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ Async safe operation failed${operationName != null ? " ($operationName)" : ""}: $e');
        print(stack);
      }
      return null;
    }
  }

  static T withDefault<T>(T? value, T defaultValue) {
    return value ?? defaultValue;
  }

  static T withFallback<T>(T Function() primary, T Function() fallback) {
    try {
      return primary();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Primary operation failed, using fallback: $e');
      }
      return fallback();
    }
  }

  // ==================== RETRY LOGIC ====================
  
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 1),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    var attempt = 0;
    
    while (true) {
      attempt++;
      
      try {
        return await operation();
      } catch (e) {
        if (attempt >= maxAttempts) {
          rethrow;
        }
        
        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }
        
        if (kDebugMode) {
          print('⚠️ Attempt $attempt failed, retrying in ${delay.inSeconds}s...');
        }
        
        await Future.delayed(delay * attempt);
      }
    }
  }

  // ==================== CIRCUIT BREAKER ====================
  
  static Future<T> withCircuitBreaker<T>(
    String operationId,
    Future<T> Function() operation, {
    int failureThreshold = 5,
    Duration resetTimeout = const Duration(minutes: 1),
  }) async {
    return await _CircuitBreaker.instance.execute(
      operationId,
      operation,
      failureThreshold: failureThreshold,
      resetTimeout: resetTimeout,
    );
  }
}

// ==================== EXCEPTIONS ====================

class StateException implements Exception {
  final String message;
  StateException(this.message);
  
  @override
  String toString() => 'StateException: $message';
}

// ==================== CIRCUIT BREAKER ====================

class _CircuitBreaker {
  static final _CircuitBreaker instance = _CircuitBreaker._();
  _CircuitBreaker._();

  final Map<String, _CircuitBreakerState> _states = {};

  Future<T> execute<T>(
    String operationId,
    Future<T> Function() operation, {
    required int failureThreshold,
    required Duration resetTimeout,
  }) async {
    _states.putIfAbsent(
      operationId,
      () => _CircuitBreakerState(failureThreshold, resetTimeout),
    );

    final state = _states[operationId]!;

    if (state.isOpen) {
      if (state.shouldAttemptReset) {
        state.halfOpen();
      } else {
        throw StateException('Circuit breaker is OPEN for $operationId');
      }
    }

    try {
      final result = await operation();
      state.onSuccess();
      return result;
    } catch (e) {
      state.onFailure();
      rethrow;
    }
  }
}

class _CircuitBreakerState {
  final int failureThreshold;
  final Duration resetTimeout;
  
  int failureCount = 0;
  bool isOpen = false;
  DateTime? lastFailureTime;

  _CircuitBreakerState(this.failureThreshold, this.resetTimeout);

  bool get shouldAttemptReset {
    if (lastFailureTime == null) return true;
    return DateTime.now().difference(lastFailureTime!) > resetTimeout;
  }

  void halfOpen() {
    if (kDebugMode) {
      print('⚡ Circuit breaker entering HALF-OPEN state');
    }
  }

  void onSuccess() {
    failureCount = 0;
    isOpen = false;
    lastFailureTime = null;
  }

  void onFailure() {
    failureCount++;
    lastFailureTime = DateTime.now();

    if (failureCount >= failureThreshold) {
      isOpen = true;
      if (kDebugMode) {
        print('🔴 Circuit breaker OPENED after $failureCount failures');
      }
    }
  }
}
