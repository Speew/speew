import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/utils.dart';

class OfflineMaps {
  Database? _db;
  final Map<String, MapTile> _memoryCache = {};

  static const int maxCacheSize = 500 * 1024 * 1024; 
  static const int maxMemoryCacheSize = 50 * 1024 * 1024; 
  static const int tileSize = 256; 
  static const int maxZoomLevel = 18;

  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _currentCacheSize = 0;

  Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/offline_maps.db';
    
    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tiles (
            id TEXT PRIMARY KEY,
            x INTEGER NOT NULL,
            y INTEGER NOT NULL,
            zoom INTEGER NOT NULL,
            data BLOB NOT NULL,
            size INTEGER NOT NULL,
            last_accessed INTEGER NOT NULL,
            access_count INTEGER DEFAULT 1,
            created_at INTEGER NOT NULL
          )
        ''');
        
        await db.execute('''
          CREATE INDEX idx_tile_coords ON tiles(x, y, zoom)
        ''');
        
        await db.execute('''
          CREATE INDEX idx_last_accessed ON tiles(last_accessed)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tiles ADD COLUMN access_count INTEGER DEFAULT 1');
        }
      },
    );

    await _calculateCacheSize();

    DebugUtils.log('Offline Maps initialized (${_formatSize(_currentCacheSize)} cached)', tag: 'MAPS');
  }

  Future<MapTile?> getTile(int x, int y, int zoom) async {
    final tileId = _getTileId(x, y, zoom);

    if (_memoryCache.containsKey(tileId)) {
      _cacheHits++;
      return _memoryCache[tileId];
    }

    final List<Map<String, dynamic>> results = await _db!.query(
      'tiles',
      where: 'id = ?',
      whereArgs: [tileId],
    );

    if (results.isNotEmpty) {
      _cacheHits++;
      
      final tile = MapTile(
        x: results[0]['x'] as int,
        y: results[0]['y'] as int,
        zoom: results[0]['zoom'] as int,
        data: results[0]['data'] as Uint8List,
      );

      await _updateTileAccess(tileId);

      _addToMemoryCache(tileId, tile);

      return tile;
    }

    _cacheMisses++;

    return await _downloadTile(x, y, zoom);
  }

  Future<MapTile?> _downloadTile(int x, int y, int zoom) async {
    try {
      
      final url = 'https:
      
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      request.headers.add('User-Agent', 'Speew/1.0');
      
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        
        final tile = MapTile(x: x, y: y, zoom: zoom, data: bytes);

        await _saveTile(tile);
        
        DebugUtils.log('Downloaded tile: $zoom/$x/$y', tag: 'MAPS');
        
        return tile;
      }
    } catch (e) {
      DebugUtils.logError('Failed to download tile', error: e);
    }
    
    return null;
  }

  Future<void> _saveTile(MapTile tile) async {
    final tileId = _getTileId(tile.x, tile.y, tile.zoom);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_currentCacheSize + tile.data.length > maxCacheSize) {
      await _evictOldTiles();
    }

    await _db!.insert(
      'tiles',
      {
        'id': tileId,
        'x': tile.x,
        'y': tile.y,
        'zoom': tile.zoom,
        'data': tile.data,
        'size': tile.data.length,
        'last_accessed': now,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _currentCacheSize += tile.data.length;
    _addToMemoryCache(tileId, tile);
  }

  Future<void> preloadArea({
    required double centerLat,
    required double centerLon,
    required int zoom,
    required int radiusTiles,
  }) async {
    final centerTile = _latLonToTile(centerLat, centerLon, zoom);
    final tilesToLoad = <MapTile>[];

    DebugUtils.log(
      'Preloading area: ${radiusTiles}x${radiusTiles} tiles at zoom $zoom',
      tag: 'MAPS',
    );

    for (int dx = -radiusTiles; dx <= radiusTiles; dx++) {
      for (int dy = -radiusTiles; dy <= radiusTiles; dy++) {
        final x = centerTile.x + dx;
        final y = centerTile.y + dy;

        final tileId = _getTileId(x, y, zoom);
        final exists = await _tileExists(tileId);

        if (!exists) {
          final tile = await _downloadTile(x, y, zoom);
          if (tile != null) {
            tilesToLoad.add(tile);
          }

          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }

    DebugUtils.log('Preloaded ${tilesToLoad.length} tiles', tag: 'MAPS');
  }

  Future<void> preloadRoute({
    required List<LatLon> waypoints,
    required int zoom,
    required int bufferTiles,
  }) async {
    final tilesToLoad = <String>{};

    for (final point in waypoints) {
      final tile = _latLonToTile(point.lat, point.lon, zoom);

      for (int dx = -bufferTiles; dx <= bufferTiles; dx++) {
        for (int dy = -bufferTiles; dy <= bufferTiles; dy++) {
          final tileId = _getTileId(tile.x + dx, tile.y + dy, zoom);
          tilesToLoad.add(tileId);
        }
      }
    }

    DebugUtils.log('Preloading route: ${tilesToLoad.length} tiles', tag: 'MAPS');

    for (final tileId in tilesToLoad) {
      final exists = await _tileExists(tileId);
      if (!exists) {
        final parts = tileId.split('_');
        if (parts.length < 4) continue; // Skip invalid tileId
        
        final x = int.tryParse(parts[1]) ?? 0;
        final y = int.tryParse(parts[2]) ?? 0;
        final z = int.tryParse(parts[3]) ?? 0;

        await _downloadTile(x, y, z);
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> _updateTileAccess(String tileId) async {
    await _db!.update(
      'tiles',
      {
        'last_accessed': DateTime.now().millisecondsSinceEpoch,
        'access_count': 1, 
      },
      where: 'id = ?',
      whereArgs: [tileId],
    );
  }

  Future<void> _evictOldTiles() async {
    
    final toRemove = (maxCacheSize * 0.2).toInt();

    final tiles = await _db!.query(
      'tiles',
      columns: ['id', 'size'],
      orderBy: 'last_accessed ASC, access_count ASC',
      limit: 100,
    );

    int removed = 0;
    for (final tile in tiles) {
      if (removed >= toRemove) break;

      await _db!.delete('tiles', where: 'id = ?', whereArgs: [tile['id']]);
      
      _memoryCache.remove(tile['id'] as String);
      removed += tile['size'] as int;
    }

    _currentCacheSize -= removed;

    DebugUtils.log('Evicted ${_formatSize(removed)} from cache', tag: 'MAPS');
  }

  void _addToMemoryCache(String tileId, MapTile tile) {
    
    int memorySize = _memoryCache.values.fold(0, (sum, t) => sum + t.data.length);

    if (memorySize + tile.data.length > maxMemoryCacheSize) {
      
      final sorted = _memoryCache.entries.toList()
        ..sort((a, b) => a.value.accessTime.compareTo(b.value.accessTime));

      for (final entry in sorted) {
        _memoryCache.remove(entry.key);
        memorySize -= entry.value.data.length;

        if (memorySize + tile.data.length <= maxMemoryCacheSize) {
          break;
        }
      }
    }

    _memoryCache[tileId] = tile;
  }

  TileCoordinate _latLonToTile(double lat, double lon, int zoom) {
    final n = 1 << zoom;
    final x = ((lon + 180.0) / 360.0 * n).floor();
    final latRad = lat * 3.14159265359 / 180.0;
    final y = ((1.0 - (latRad.tan() + 1.0 / latRad.cos()).log() / 3.14159265359) / 2.0 * n).floor();

    return TileCoordinate(x: x, y: y, zoom: zoom);
  }

  String _getTileId(int x, int y, int zoom) => 'tile_${x}_${y}_$zoom';

  Future<bool> _tileExists(String tileId) async {
    final result = await _db!.query('tiles', where: 'id = ?', whereArgs: [tileId]);
    return result.isNotEmpty;
  }

  Future<void> _calculateCacheSize() async {
    final result = await _db!.rawQuery('SELECT SUM(size) as total FROM tiles');
    _currentCacheSize = result[0]['total'] as int? ?? 0;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> getStatistics() {
    final hitRate = _cacheHits + _cacheMisses > 0
        ? (_cacheHits / (_cacheHits + _cacheMisses) * 100)
        : 0.0;

    return {
      'cache_size': _formatSize(_currentCacheSize),
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'hit_rate': '${hitRate.toStringAsFixed(1)}%',
      'memory_cache_tiles': _memoryCache.length,
    };
  }

  Future<void> clearCache() async {
    await _db!.delete('tiles');
    _memoryCache.clear();
    _currentCacheSize = 0;
    _cacheHits = 0;
    _cacheMisses = 0;

    DebugUtils.log('Cache cleared', tag: 'MAPS');
  }

  Future<void> dispose() async {
    await _db?.close();
  }
}

class MapTile {
  final int x;
  final int y;
  final int zoom;
  final Uint8List data;
  DateTime accessTime;

  MapTile({
    required this.x,
    required this.y,
    required this.zoom,
    required this.data,
  }) : accessTime = DateTime.now();
}

class TileCoordinate {
  final int x;
  final int y;
  final int zoom;

  TileCoordinate({required this.x, required this.y, required this.zoom});
}

class LatLon {
  final double lat;
  final double lon;

  LatLon(this.lat, this.lon);
}

class OfflineMapRenderer {
  final OfflineMaps _maps;

  OfflineMapRenderer(this._maps);

  Future<List<MapTile>> renderViewport({
    required double centerLat,
    required double centerLon,
    required int zoom,
    required int viewportWidth,
    required int viewportHeight,
  }) async {
    final tiles = <MapTile>[];

    final tilesX = (viewportWidth / OfflineMaps.tileSize).ceil() + 1;
    final tilesY = (viewportHeight / OfflineMaps.tileSize).ceil() + 1;

    final centerTile = _maps._latLonToTile(centerLat, centerLon, zoom);

    for (int dx = -tilesX ~/ 2; dx <= tilesX ~/ 2; dx++) {
      for (int dy = -tilesY ~/ 2; dy <= tilesY ~/ 2; dy++) {
        final tile = await _maps.getTile(
          centerTile.x + dx,
          centerTile.y + dy,
          zoom,
        );

        if (tile != null) {
          tiles.add(tile);
        }
      }
    }

    return tiles;
  }
}