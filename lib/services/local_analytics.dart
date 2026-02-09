import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../core/utils.dart';

class LocalAnalytics {
  Database? _db;
  
  final Map<String, EventAggregator> _aggregators = {};
  Timer? _flushTimer;

  Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/local_analytics.db';
    
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT NOT NULL,
            action TEXT NOT NULL,
            label TEXT,
            value REAL,
            timestamp INTEGER NOT NULL,
            session_id TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            value REAL NOT NULL,
            unit TEXT,
            timestamp INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            duration INTEGER,
            events_count INTEGER DEFAULT 0
          )
        ''');

        await db.execute('CREATE INDEX idx_events_category ON events(category)');
        await db.execute('CREATE INDEX idx_events_timestamp ON events(timestamp)');
        await db.execute('CREATE INDEX idx_metrics_name ON metrics(name)');
      },
    );

    _startPeriodicFlush();

    DebugUtils.log('Local Analytics initialized', tag: 'ANALYTICS');
  }

  Future<void> trackEvent({
    required String category,
    required String action,
    String? label,
    double? value,
  }) async {
    final event = AnalyticsEvent(
      category: category,
      action: action,
      label: label,
      value: value,
      timestamp: DateTime.now(),
      sessionId: _getCurrentSessionId(),
    );

    final key = '${category}_$action';
    _aggregators[key] ??= EventAggregator();
    _aggregators[key]!.add(event);

    await _saveEvent(event);
  }

  Future<void> trackMetric({
    required String name,
    required double value,
    String? unit,
  }) async {
    await _db!.insert('metrics', {
      'name': name,
      'value': value,
      'unit': unit,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> trackScreenTime(String screenName, Duration duration) async {
    await trackEvent(
      category: 'screen',
      action: 'view',
      label: screenName,
      value: duration.inSeconds.toDouble(),
    );
  }

  Future<void> trackPerformance({
    required String operation,
    required Duration duration,
    Map<String, dynamic>? metadata,
  }) async {
    await trackEvent(
      category: 'performance',
      action: operation,
      label: jsonEncode(metadata ?? {}),
      value: duration.inMilliseconds.toDouble(),
    );

    await trackMetric(
      name: 'perf_$operation',
      value: duration.inMilliseconds.toDouble(),
      unit: 'ms',
    );
  }

  Future<void> trackNetworkUsage({
    required int bytesReceived,
    required int bytesSent,
  }) async {
    await trackMetric(
      name: 'network_received',
      value: bytesReceived.toDouble(),
      unit: 'bytes',
    );

    await trackMetric(
      name: 'network_sent',
      value: bytesSent.toDouble(),
      unit: 'bytes',
    );
  }

  Future<void> trackBatteryUsage(double percentage) async {
    await trackMetric(
      name: 'battery_level',
      value: percentage,
      unit: '%',
    );
  }

  Future<EventStatistics> getEventStatistics({
    required String category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
    final end = endDate ?? DateTime.now();

    final events = await _db!.query(
      'events',
      where: 'category = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [category, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );

    if (events.isEmpty) {
      return EventStatistics(
        category: category,
        totalCount: 0,
        uniqueActions: 0,
        averageValue: 0.0,
      );
    }

    final uniqueActions = events.map((e) => e['action']).toSet().length;
    
    final values = events
        .where((e) => e['value'] != null)
        .map((e) => e['value'] as double)
        .toList();

    final averageValue = values.isNotEmpty
        ? values.reduce((a, b) => a + b) / values.length
        : 0.0;

    return EventStatistics(
      category: category,
      totalCount: events.length,
      uniqueActions: uniqueActions,
      averageValue: averageValue,
      topActions: await _getTopActions(category, 5),
    );
  }

  Future<Map<String, MetricSummary>> getMetricsSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
    final end = endDate ?? DateTime.now();

    final metrics = await _db!.query(
      'metrics',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );

    final summary = <String, MetricSummary>{};

    final grouped = <String, List<double>>{};
    for (final metric in metrics) {
      final name = metric['name'] as String;
      final value = metric['value'] as double;

      grouped[name] ??= [];
      grouped[name]!.add(value);
    }

    for (final entry in grouped.entries) {
      final values = entry.value;
      values.sort();

      summary[entry.key] = MetricSummary(
        name: entry.key,
        count: values.length,
        min: values.first,
        max: values.last,
        average: values.reduce((a, b) => a + b) / values.length,
        median: values[values.length ~/ 2],
      );
    }

    return summary;
  }

  Future<UsageInsights> getUsageInsights() async {
    final now = DateTime.now();
    final last7Days = now.subtract(const Duration(days: 7));
    final last30Days = now.subtract(const Duration(days: 30));

    final sessions7d = await _db!.query(
      'sessions',
      where: 'started_at >= ?',
      whereArgs: [last7Days.millisecondsSinceEpoch],
    );

    final sessionDurations = sessions7d
        .where((s) => s['duration'] != null)
        .map((s) => s['duration'] as int)
        .toList();

    final avgSessionDuration = sessionDurations.isNotEmpty
        ? sessionDurations.reduce((a, b) => a + b) / sessionDurations.length
        : 0.0;

    final topEvents = await _getTopEvents(7);

    final perfMetrics = await getMetricsSummary(startDate: last7Days);

    final networkSent = perfMetrics['network_sent'];
    final networkReceived = perfMetrics['network_received'];

    return UsageInsights(
      sessionsLast7Days: sessions7d.length,
      averageSessionDuration: Duration(milliseconds: avgSessionDuration.round()),
      topEvents: topEvents,
      networkUsage: NetworkUsage(
        bytesSent: networkSent?.average.round() ?? 0,
        bytesReceived: networkReceived?.average.round() ?? 0,
      ),
      performanceScore: _calculatePerformanceScore(perfMetrics),
    );
  }

  Future<DailyReport> getDailyReport(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final events = await _db!.query(
      'events',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
    );

    final metrics = await _db!.query(
      'metrics',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
    );

    final sessions = await _db!.query(
      'sessions',
      where: 'started_at >= ? AND started_at < ?',
      whereArgs: [
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
    );

    return DailyReport(
      date: date,
      totalEvents: events.length,
      totalMetrics: metrics.length,
      totalSessions: sessions.length,
      topCategories: await _getTopCategories(startOfDay, endOfDay),
    );
  }

  Future<String> exportData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    final events = await _db!.query(
      'events',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );

    final metrics = await _db!.query(
      'metrics',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );

    final sessions = await _db!.query(
      'sessions',
      where: 'started_at >= ? AND started_at <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );

    final export = {
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'start_date': start.toIso8601String(),
      'end_date': end.toIso8601String(),
      'events': events,
      'metrics': metrics,
      'sessions': sessions,
    };

    return jsonEncode(export);
  }

  Future<void> cleanOldData({int daysToKeep = 90}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    await _db!.delete(
      'events',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );

    await _db!.delete(
      'metrics',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );

    await _db!.delete(
      'sessions',
      where: 'started_at < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );

    DebugUtils.log('Cleaned data older than $daysToKeep days', tag: 'ANALYTICS');
  }

  Future<void> _saveEvent(AnalyticsEvent event) async {
    await _db!.insert('events', event.toJson());
  }

  Future<List<Map<String, dynamic>>> _getTopActions(String category, int limit) async {
    return await _db!.rawQuery('''
      SELECT action, COUNT(*) as count
      FROM events
      WHERE category = ?
      GROUP BY action
      ORDER BY count DESC
      LIMIT ?
    ''', [category, limit]);
  }

  Future<List<Map<String, dynamic>>> _getTopEvents(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));

    return await _db!.rawQuery('''
      SELECT category, action, COUNT(*) as count
      FROM events
      WHERE timestamp >= ?
      GROUP BY category, action
      ORDER BY count DESC
      LIMIT 10
    ''', [cutoff.millisecondsSinceEpoch]);
  }

  Future<List<Map<String, dynamic>>> _getTopCategories(
    DateTime start,
    DateTime end,
  ) async {
    return await _db!.rawQuery('''
      SELECT category, COUNT(*) as count
      FROM events
      WHERE timestamp >= ? AND timestamp < ?
      GROUP BY category
      ORDER BY count DESC
      LIMIT 5
    ''', [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);
  }

  double _calculatePerformanceScore(Map<String, MetricSummary> metrics) {

    double score = 100.0;

    final avgLatency = metrics.values
        .where((m) => m.name.contains('perf_'))
        .map((m) => m.average)
        .fold(0.0, (a, b) => a + b);

    if (avgLatency > 1000) score -= 20; 
    else if (avgLatency > 500) score -= 10; 

    return score.clamp(0, 100);
  }

  void _startPeriodicFlush() {
    _flushTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _flushAggregators();
    });
  }

  void _flushAggregators() {
    
    _aggregators.clear();
  }

  String _getCurrentSessionId() {
    
    return 'session_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await _db?.close();
  }
}

class AnalyticsEvent {
  final String category;
  final String action;
  final String? label;
  final double? value;
  final DateTime timestamp;
  final String sessionId;

  AnalyticsEvent({
    required this.category,
    required this.action,
    this.label,
    this.value,
    required this.timestamp,
    required this.sessionId,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'action': action,
    'label': label,
    'value': value,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'session_id': sessionId,
  };
}

class EventAggregator {
  final List<AnalyticsEvent> events = [];
  
  void add(AnalyticsEvent event) {
    events.add(event);
  }
}

class EventStatistics {
  final String category;
  final int totalCount;
  final int uniqueActions;
  final double averageValue;
  final List<Map<String, dynamic>>? topActions;

  EventStatistics({
    required this.category,
    required this.totalCount,
    required this.uniqueActions,
    required this.averageValue,
    this.topActions,
  });
}

class MetricSummary {
  final String name;
  final int count;
  final double min;
  final double max;
  final double average;
  final double median;

  MetricSummary({
    required this.name,
    required this.count,
    required this.min,
    required this.max,
    required this.average,
    required this.median,
  });
}

class UsageInsights {
  final int sessionsLast7Days;
  final Duration averageSessionDuration;
  final List<Map<String, dynamic>> topEvents;
  final NetworkUsage networkUsage;
  final double performanceScore;

  UsageInsights({
    required this.sessionsLast7Days,
    required this.averageSessionDuration,
    required this.topEvents,
    required this.networkUsage,
    required this.performanceScore,
  });
}

class NetworkUsage {
  final int bytesSent;
  final int bytesReceived;

  NetworkUsage({
    required this.bytesSent,
    required this.bytesReceived,
  });

  int get totalBytes => bytesSent + bytesReceived;
}

class DailyReport {
  final DateTime date;
  final int totalEvents;
  final int totalMetrics;
  final int totalSessions;
  final List<Map<String, dynamic>> topCategories;

  DailyReport({
    required this.date,
    required this.totalEvents,
    required this.totalMetrics,
    required this.totalSessions,
    required this.topCategories,
  });
}