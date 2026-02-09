import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Simple Logger Service - Debug helper
/// Provides clean, color-coded logging for development
class LoggerService {
  static const String _appTag = 'Speew';
  
  // Log levels
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(
        message,
        name: tag ?? _appTag,
        level: 500, // Debug level
      );
    }
  }
  
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(
        '✅ $message',
        name: tag ?? _appTag,
        level: 800, // Info level
      );
    }
  }
  
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(
        '⚠️ $message',
        name: tag ?? _appTag,
        level: 900, // Warning level
      );
    }
  }
  
  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    if (kDebugMode) {
      developer.log(
        '❌ $message',
        name: tag ?? _appTag,
        level: 1000, // Error level
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  
  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(
        '🎉 $message',
        name: tag ?? _appTag,
        level: 800,
      );
    }
  }
  
  static void network(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(
        '🌐 $message',
        name: tag ?? _appTag,
        level: 500,
      );
    }
  }
  
  static void database(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(
        '💾 $message',
        name: tag ?? _appTag,
        level: 500,
      );
    }
  }
}
