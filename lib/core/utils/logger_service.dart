import '../../core/config/app_config.dart';
import '../../core/utils/logger_service.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

/// Níveis de log disponíveis
enum LogLevel {
  debug,
  info,
  warn,
  error,
}

/// Serviço centralizado de logging
/// 
/// Substitui todos os print() por chamadas estruturadas com níveis de log
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  /// Lista de logs armazenados em memória (para debug)
  final List<LogEntry> _logs = [];

  /// Máximo de logs em memória
  static const int _maxLogsInMemory = 1000;

  /// Log de debug (apenas em desenvolvimento)
  void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (AppConfig.enableDebugLogs && AppConfig.isDevelopment) {
      _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Log de informação
  void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (AppConfig.enableInfoLogs) {
      _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Log de aviso
  void warn(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (AppConfig.enableWarningLogs) {
      _log(LogLevel.warn, message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Log de erro
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (AppConfig.enableErrorLogs) {
      _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Método interno de log
  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now();
    final entry = LogEntry(
      level: level,
      message: message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      timestamp: timestamp,
    );

    // Adiciona à lista em memória
    _logs.add(entry);
    if (_logs.length > _maxLogsInMemory) {
      _logs.removeAt(0);
    }

    // Imprime no console
    final prefix = _getLevelPrefix(level);
    final tagStr = tag != null ? '[$tag] ' : '';
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';

    if (kDebugMode) {
      logger.debug('$timeStr $prefix $tagStr$message');
      if (error != null) {
        logger.debug('  Error: $error');
      }
      if (stackTrace != null) {
        logger.debug('  StackTrace: $stackTrace');
      }
    }
  }

  /// Retorna o prefixo visual do nível de log
  String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍 [DEBUG]';
      case LogLevel.info:
        return 'ℹ️  [INFO]';
      case LogLevel.warn:
        return '⚠️  [WARN]';
      case LogLevel.error:
        return '❌ [ERROR]';
    }
  }

  /// Retorna todos os logs em memória
  List<LogEntry> getLogs({LogLevel? level}) {
    if (level == null) {
      return List.unmodifiable(_logs);
    }
    return _logs.where((log) => log.level == level).toList();
  }

  /// Limpa todos os logs em memória
  void clearLogs() {
    _logs.clear();
  }

  /// Exporta logs como string
  String exportLogs() {
    final buffer = StringBuffer();
    for (final log in _logs) {
      buffer.writeln(log.toString());
    }
    return buffer.toString();
  }
}

/// Entrada de log individual
class LogEntry {
  final LogLevel level;
  final String message;
  final String? tag;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    this.tag,
    this.error,
    this.stackTrace,
    required this.timestamp,
  });

  @override
  String toString() {
    final tagStr = tag != null ? '[$tag] ' : '';
    final errorStr = error != null ? '\n  Error: $error' : '';
    final stackStr = stackTrace != null ? '\n  Stack: $stackTrace' : '';
    return '${timestamp.toIso8601String()} [${level.name.toUpperCase()}] $tagStr$message$errorStr$stackStr';
  }
}

/// Instância global do logger para acesso rápido
final logger = LoggerService();
