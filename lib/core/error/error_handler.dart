import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ErrorHandler {
  static GlobalKey<NavigatorState>? _navigatorKey;
  static final List<AppError> _errorLog = [];
  static const int maxErrorLogSize = 100;
  
  static void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError(
        AppError(
          message: details.exceptionAsString(),
          stackTrace: details.stack,
          timestamp: DateTime.now(),
          type: ErrorType.flutter,
        ),
      );
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError(
        AppError(
          message: error.toString(),
          stackTrace: stack,
          timestamp: DateTime.now(),
          type: ErrorType.platform,
        ),
      );
      return true;
    };
  }
  
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }
  
  static void handleError(dynamic error, [StackTrace? stackTrace]) {
    final appError = AppError(
      message: error.toString(),
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      type: ErrorType.app,
    );
    
    _logError(appError);
    
    if (kDebugMode) {
      debugPrint('Error: ${appError.message}');
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }
  
  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  static void _logError(AppError error) {
    _errorLog.add(error);
    
    if (_errorLog.length > maxErrorLogSize) {
      _errorLog.removeAt(0);
    }
  }
  
  static List<AppError> getErrorLog() {
    return List.unmodifiable(_errorLog);
  }
  
  static void clearErrorLog() {
    _errorLog.clear();
  }
}

class AppError {
  final String message;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final ErrorType type;
  
  AppError({
    required this.message,
    this.stackTrace,
    required this.timestamp,
    required this.type,
  });
  
  @override
  String toString() {
    return 'AppError{message: $message, type: $type, timestamp: $timestamp}';
  }
}

enum ErrorType {
  flutter,
  platform,
  app,
  network,
  storage,
  permission,
}

// Custom Exceptions
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  
  @override
  String toString() => 'NetworkException: $message';
}

class StorageException implements Exception {
  final String message;
  StorageException(this.message);
  
  @override
  String toString() => 'StorageException: $message';
}

class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);
  
  @override
  String toString() => 'EncryptionException: $message';
}

class PermissionException implements Exception {
  final String message;
  PermissionException(this.message);
  
  @override
  String toString() => 'PermissionException: $message';
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  
  @override
  String toString() => 'ValidationException: $message';
}
