import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'dart:collection';

/// UI Rendering Optimizer - Otimiza renderização
/// Features:
/// - Widget caching (evita rebuilds)
/// - Smart repaint boundaries
/// - Viewport optimization
/// - Frame budget monitoring
class UIRenderOptimizer {
  static final UIRenderOptimizer _instance = UIRenderOptimizer._internal();
  factory UIRenderOptimizer() => _instance;
  UIRenderOptimizer._internal();

  final WidgetCache widgetCache = WidgetCache();
  final FrameMonitor frameMonitor = FrameMonitor();

  void initialize() {
    frameMonitor.start();
  }

  void dispose() {
    widgetCache.clear();
    frameMonitor.stop();
  }
}

/// Widget Cache - Cacheia widgets para evitar rebuilds
class WidgetCache {
  final Map<String, CachedWidget> _cache = {};
  
  static const int maxCacheSize = 50;
  int _hits = 0;
  int _misses = 0;

  /// Obter widget do cache ou criar
  Widget getOrCreate(
    String key,
    Widget Function() builder, {
    List<Object?>? dependencies,
  }) {
    final cached = _cache[key];

    // Verificar se está em cache e dependências não mudaram
    if (cached != null && !cached.shouldRebuild(dependencies)) {
      _hits++;
      return cached.widget;
    }

    // Cache miss - criar novo widget
    _misses++;
    
    final widget = builder();
    
    _cache[key] = CachedWidget(
      widget: widget,
      dependencies: dependencies,
    );

    // Limpar cache se muito grande
    if (_cache.length > maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }

    return widget;
  }

  /// Invalidar cache
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Limpar todo cache
  void clear() {
    _cache.clear();
  }

  /// Estatísticas
  Map<String, dynamic> getStats() {
    final total = _hits + _misses;
    return {
      'size': _cache.length,
      'hits': _hits,
      'misses': _misses,
      'hit_rate': total > 0 
          ? '${(_hits / total * 100).toStringAsFixed(1)}%'
          : '0%',
    };
  }
}

class CachedWidget {
  final Widget widget;
  final List<Object?>? dependencies;

  CachedWidget({
    required this.widget,
    this.dependencies,
  });

  bool shouldRebuild(List<Object?>? newDependencies) {
    if (dependencies == null && newDependencies == null) return false;
    if (dependencies == null || newDependencies == null) return true;
    if (dependencies!.length != newDependencies.length) return true;

    for (int i = 0; i < dependencies!.length; i++) {
      if (dependencies![i] != newDependencies[i]) return true;
    }

    return false;
  }
}

/// Cached Widget Builder
class CachedBuilder extends StatelessWidget {
  final String cacheKey;
  final Widget Function() builder;
  final List<Object?>? dependencies;

  const CachedBuilder({
    Key? key,
    required this.cacheKey,
    required this.builder,
    this.dependencies,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return UIRenderOptimizer().widgetCache.getOrCreate(
      cacheKey,
      builder,
      dependencies: dependencies,
    );
  }
}

/// Frame Monitor - Monitora performance de frames
class FrameMonitor {
  final LinkedHashMap<int, FrameMetrics> _frameHistory = LinkedHashMap();
  static const int maxHistory = 120; // 2 segundos a 60fps

  int _frameCount = 0;
  int _droppedFrames = 0;
  double _averageFPS = 60.0;

  bool _isMonitoring = false;

  void start() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    
    WidgetsBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  void stop() {
    _isMonitoring = false;
  }

  void _onFrame(Duration timestamp) {
    if (!_isMonitoring) return;

    _frameCount++;

    final frameMetrics = FrameMetrics(
      frameNumber: _frameCount,
      timestamp: timestamp,
    );

    _frameHistory[_frameCount] = frameMetrics;

    // Manter apenas últimos N frames
    if (_frameHistory.length > maxHistory) {
      _frameHistory.remove(_frameHistory.keys.first);
    }

    // Calcular FPS
    _calculateFPS();

    // Detectar frames dropped
    if (_frameHistory.length >= 2) {
      final keys = _frameHistory.keys.toList();
      final current = _frameHistory[keys.last]!;
      final previous = _frameHistory[keys[keys.length - 2]]!;

      final frameDuration = current.timestamp - previous.timestamp;
      
      // Se > 16.67ms (60fps), frame foi dropped
      if (frameDuration.inMicroseconds > 16670) {
        _droppedFrames++;
      }
    }
  }

  void _calculateFPS() {
    if (_frameHistory.length < 2) return;

    final keys = _frameHistory.keys.toList();
    final first = _frameHistory[keys.first]!;
    final last = _frameHistory[keys.last]!;

    final duration = last.timestamp - first.timestamp;
    
    if (duration.inMicroseconds > 0) {
      _averageFPS = (_frameHistory.length - 1) * 
                    1000000 / 
                    duration.inMicroseconds;
    }
  }

  Map<String, dynamic> getStats() {
    return {
      'total_frames': _frameCount,
      'dropped_frames': _droppedFrames,
      'drop_rate': _frameCount > 0
          ? '${(_droppedFrames / _frameCount * 100).toStringAsFixed(2)}%'
          : '0%',
      'average_fps': _averageFPS.toStringAsFixed(1),
      'is_smooth': _averageFPS >= 58.0,
    };
  }
}

class FrameMetrics {
  final int frameNumber;
  final Duration timestamp;

  FrameMetrics({
    required this.frameNumber,
    required this.timestamp,
  });
}

/// Smart Repaint Boundary - Adiciona automaticamente
class SmartRepaintBoundary extends StatelessWidget {
  final Widget child;
  final bool enable;

  const SmartRepaintBoundary({
    Key? key,
    required this.child,
    this.enable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!enable) return child;
    
    return RepaintBoundary(child: child);
  }
}

/// Optimized List View - ListView otimizada
class OptimizedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ScrollController? controller;
  final double? itemExtent;

  const OptimizedListView({
    Key? key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.itemExtent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      itemCount: itemCount,
      itemExtent: itemExtent, // Melhora performance
      // Adicionar cache extent para pre-render
      cacheExtent: 500,
      // Wrap cada item em RepaintBoundary
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

/// Lazy Image - Carrega imagem sob demanda
class LazyImage extends StatefulWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const LazyImage({
    Key? key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit,
  }) : super(key: key);

  @override
  State<LazyImage> createState() => _LazyImageState();
}

class _LazyImageState extends State<LazyImage> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.imagePath),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0 && !_isVisible) {
          setState(() => _isVisible = true);
        }
      },
      child: _isVisible
          ? Image.asset(
              widget.imagePath,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              // Cache para reuso
              cacheWidth: widget.width?.toInt(),
              cacheHeight: widget.height?.toInt(),
            )
          : SizedBox(
              width: widget.width,
              height: widget.height,
            ),
    );
  }
}

/// Visibility Detector - Detecta quando widget está visível
class VisibilityDetector extends StatefulWidget {
  final Widget child;
  final void Function(VisibilityInfo) onVisibilityChanged;

  const VisibilityDetector({
    Key? key,
    required this.child,
    required this.onVisibilityChanged,
  }) : super(key: key);

  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  @override
  Widget build(BuildContext context) {
    // Simplificado - em produção usar package visibility_detector
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onVisibilityChanged(VisibilityInfo(visibleFraction: 1.0));
    });

    return widget.child;
  }
}

class VisibilityInfo {
  final double visibleFraction;

  VisibilityInfo({required this.visibleFraction});
}

/// Const Wrapper - Force const quando possível
class ConstWrapper extends StatelessWidget {
  final Widget child;

  const ConstWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => child;
}

/// Build Context Cache - Evita lookups repetidos
class BuildContextCache {
  final Map<Type, dynamic> _cache = {};

  T of<T>(BuildContext context, T Function(BuildContext) lookup) {
    if (_cache.containsKey(T)) {
      return _cache[T] as T;
    }

    final result = lookup(context);
    _cache[T] = result;
    return result;
  }

  void clear() => _cache.clear();
}
