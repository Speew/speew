import 'dart:async';

/// Simple Cache Service
/// In-memory cache with TTL (Time To Live)
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, _CacheItem> _cache = {};
  Timer? _cleanupTimer;

  void initialize() {
    // Auto cleanup every 5 minutes
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _cleanup(),
    );
  }

  /// Set cache with optional TTL
  void set(String key, dynamic value, {Duration ttl = const Duration(minutes: 30)}) {
    _cache[key] = _CacheItem(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Get cached value
  T? get<T>(String key) {
    final item = _cache[key];
    if (item == null) return null;

    // Check if expired
    if (item.isExpired) {
      _cache.remove(key);
      return null;
    }

    return item.value as T?;
  }

  /// Check if key exists and not expired
  bool has(String key) {
    final item = _cache[key];
    if (item == null) return false;

    if (item.isExpired) {
      _cache.remove(key);
      return false;
    }

    return true;
  }

  /// Remove specific key
  void remove(String key) {
    _cache.remove(key);
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
  }

  /// Remove expired items
  void _cleanup() {
    _cache.removeWhere((key, item) => item.isExpired);
  }

  /// Get cache statistics
  Map<String, int> getStats() {
    return {
      'total': _cache.length,
      'expired': _cache.values.where((item) => item.isExpired).length,
    };
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}

class _CacheItem {
  final dynamic value;
  final DateTime expiresAt;

  _CacheItem({
    required this.value,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
