import 'package:sqflite/sqflite.dart';
import 'dart:async';

/// Database Query Optimizer
/// Otimiza queries do SQLite para máxima performance
class DatabaseQueryOptimizer {
  final Database db;
  
  // Query cache
  final Map<String, QueryResult> _queryCache = {};
  static const Duration cacheTTL = Duration(minutes: 5);
  
  // Prepared statements pool
  final Map<String, String> _preparedStatements = {};
  
  // Batch operations
  final List<BatchOperation> _pendingBatch = [];
  Timer? _batchTimer;
  
  DatabaseQueryOptimizer(this.db) {
    _initializeOptimizations();
  }

  /// Inicializar otimizações no banco
  Future<void> _initializeOptimizations() async {
    // Enable WAL mode (Write-Ahead Logging) para melhor concorrência
    await db.execute('PRAGMA journal_mode=WAL');
    
    // Aumentar cache size
    await db.execute('PRAGMA cache_size=10000'); // 10MB
    
    // Otimizar sincronização
    await db.execute('PRAGMA synchronous=NORMAL');
    
    // Temp store em memória
    await db.execute('PRAGMA temp_store=MEMORY');
    
    // Análise automática para otimizar query planner
    await db.execute('PRAGMA optimize');
  }

  /// Query otimizada com cache
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    bool useCache = true,
  }) async {
    final cacheKey = _buildCacheKey(
      table, distinct, columns, where, whereArgs, 
      groupBy, having, orderBy, limit, offset,
    );

    // Verificar cache
    if (useCache && _queryCache.containsKey(cacheKey)) {
      final cached = _queryCache[cacheKey]!;
      if (!cached.isExpired) {
        return cached.result;
      }
    }

    // Executar query
    final result = await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    // Cachear resultado
    if (useCache) {
      _queryCache[cacheKey] = QueryResult(result, cacheTTL);
    }

    return result;
  }

  /// Insert com batching automático
  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    bool batch = true,
  }) async {
    if (batch) {
      _pendingBatch.add(BatchOperation(
        type: BatchType.insert,
        table: table,
        values: values,
      ));
      
      _scheduleBatchFlush();
      
      return 0; // ID será retornado após flush
    }

    return await db.insert(table, values);
  }

  /// Update com batching
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    bool batch = true,
  }) async {
    if (batch) {
      _pendingBatch.add(BatchOperation(
        type: BatchType.update,
        table: table,
        values: values,
        where: where,
        whereArgs: whereArgs,
      ));
      
      _scheduleBatchFlush();
      
      return 0;
    }

    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  /// Delete com batching
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    bool batch = true,
  }) async {
    if (batch) {
      _pendingBatch.add(BatchOperation(
        type: BatchType.delete,
        table: table,
        where: where,
        whereArgs: whereArgs,
      ));
      
      _scheduleBatchFlush();
      
      return 0;
    }

    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Flush do batch
  Future<void> flushBatch() async {
    if (_pendingBatch.isEmpty) return;

    final batch = db.batch();
    final operations = List<BatchOperation>.from(_pendingBatch);
    _pendingBatch.clear();

    for (final op in operations) {
      switch (op.type) {
        case BatchType.insert:
          batch.insert(op.table, op.values!);
          break;
        case BatchType.update:
          batch.update(
            op.table, 
            op.values!, 
            where: op.where, 
            whereArgs: op.whereArgs,
          );
          break;
        case BatchType.delete:
          batch.delete(
            op.table, 
            where: op.where, 
            whereArgs: op.whereArgs,
          );
          break;
      }
    }

    await batch.commit(noResult: true);
    
    // Invalidar cache após modificações
    _invalidateCache();
  }

  /// Agendar flush do batch
  void _scheduleBatchFlush() {
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 500), () {
      flushBatch();
    });
  }

  /// Query raw otimizada
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
    bool useCache = true,
  ]) async {
    final cacheKey = '$sql:${arguments?.join(',')}';

    if (useCache && _queryCache.containsKey(cacheKey)) {
      final cached = _queryCache[cacheKey]!;
      if (!cached.isExpired) {
        return cached.result;
      }
    }

    final result = await db.rawQuery(sql, arguments);

    if (useCache) {
      _queryCache[cacheKey] = QueryResult(result, cacheTTL);
    }

    return result;
  }

  /// Bulk insert otimizado
  Future<void> bulkInsert(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;

    final batch = db.batch();

    for (final row in rows) {
      batch.insert(table, row);
    }

    await batch.commit(noResult: true);
    _invalidateCache();
  }

  /// Criar índice se não existir
  Future<void> createIndexIfNotExists(
    String indexName,
    String table,
    List<String> columns, {
    bool unique = false,
  }) async {
    final sql = '''
      CREATE INDEX IF NOT EXISTS $indexName 
      ON $table (${columns.join(', ')})
    ''';

    await db.execute(sql);
  }

  /// Analisar e otimizar tabela
  Future<void> analyzeTable(String table) async {
    await db.execute('ANALYZE $table');
  }

  /// Vacuum (compactar banco)
  Future<void> vacuum() async {
    await db.execute('VACUUM');
  }

  /// Invalidar cache
  void _invalidateCache() {
    _queryCache.clear();
  }

  /// Construir chave de cache
  String _buildCacheKey(
    String table,
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  ) {
    return [
      table,
      distinct,
      columns?.join(','),
      where,
      whereArgs?.join(','),
      groupBy,
      having,
      orderBy,
      limit,
      offset,
    ].join(':');
  }

  /// Estatísticas do otimizador
  Map<String, dynamic> getStats() {
    return {
      'cache_size': _queryCache.length,
      'pending_batch': _pendingBatch.length,
      'cache_hit_rate': 'N/A', // Implementar tracking
    };
  }

  void dispose() {
    _batchTimer?.cancel();
    _queryCache.clear();
    _pendingBatch.clear();
  }
}

class QueryResult {
  final List<Map<String, dynamic>> result;
  final DateTime expiresAt;

  QueryResult(this.result, Duration ttl)
      : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class BatchOperation {
  final BatchType type;
  final String table;
  final Map<String, dynamic>? values;
  final String? where;
  final List<dynamic>? whereArgs;

  BatchOperation({
    required this.type,
    required this.table,
    this.values,
    this.where,
    this.whereArgs,
  });
}

enum BatchType { insert, update, delete }

/// Index Builder - Cria índices otimizados
class IndexBuilder {
  final DatabaseQueryOptimizer optimizer;

  IndexBuilder(this.optimizer);

  /// Criar índices para mensagens
  Future<void> createMessageIndexes() async {
    await optimizer.createIndexIfNotExists(
      'idx_messages_peer_timestamp',
      'messages',
      ['peer_id', 'timestamp'],
    );

    await optimizer.createIndexIfNotExists(
      'idx_messages_timestamp',
      'messages',
      ['timestamp'],
    );

    await optimizer.createIndexIfNotExists(
      'idx_messages_status',
      'messages',
      ['status'],
    );
  }

  /// Criar índices para peers
  Future<void> createPeerIndexes() async {
    await optimizer.createIndexIfNotExists(
      'idx_peers_last_seen',
      'peers',
      ['last_seen'],
    );

    await optimizer.createIndexIfNotExists(
      'idx_peers_connected',
      'peers',
      ['is_connected'],
    );
  }

  /// Criar todos os índices
  Future<void> createAllIndexes() async {
    await Future.wait([
      createMessageIndexes(),
      createPeerIndexes(),
    ]);
  }
}
