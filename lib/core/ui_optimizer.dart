import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// UI Optimizer - Otimizações para interface
/// Features:
/// - Frame rate monitoring
/// - Jank detection
/// - Widget rebuild optimization
/// - Scroll optimization
class UIOptimizer {
  static final UIOptimizer _instance = UIOptimizer._internal();
  factory UIOptimizer() => _instance;
  UIOptimizer._internal();

  // Frame monitoring
  final List<Duration> _frameTimes = [];
  int _jankCount = 0;
  double _averageFPS = 60.0;

  Timer? _monitoringTimer;

  /// Inicializar
  void initialize() {
    WidgetsBinding.instance.addTimingsCallback(_onFrameCallback);
    _startMonitoring();
  }

  /// Callback de frame
  void _onFrameCallback(List<FrameTiming> timings) {
    for (final timing in timings) {
      final frameDuration = timing.totalSpan;
      _frameTimes.add(frameDuration);

      // Detectar jank (frame > 16.67ms = < 60 FPS)
      if (frameDuration.inMilliseconds > 16) {
        _jankCount++;
      }
    }

    // Manter apenas últimos 100 frames
    if (_frameTimes.length > 100) {
      _frameTimes.removeRange(0, _frameTimes.length - 100);
    }

    _calculateAverageFPS();
  }

  /// Calcular FPS médio
  void _calculateAverageFPS() {
    if (_frameTimes.isEmpty) return;

    final totalMs = _frameTimes.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );

    final avgMs = totalMs / _frameTimes.length;
    _averageFPS = 1000 / avgMs;
  }

  /// Monitoramento periódico
  void _startMonitoring() {
    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _logPerformance(),
    );
  }

  void _logPerformance() {
    debugPrint('🎯 UI Performance:');
    debugPrint('   Average FPS: ${_averageFPS.toStringAsFixed(1)}');
    debugPrint('   Jank count: $_jankCount');
    debugPrint('   Frame times: ${_frameTimes.length}');
  }

  /// Obter estatísticas
  Map<String, dynamic> getStats() {
    return {
      'average_fps': _averageFPS.toStringAsFixed(1),
      'jank_count': _jankCount,
      'frame_samples': _frameTimes.length,
      'performance_rating': _getPerformanceRating(),
    };
  }

  String _getPerformanceRating() {
    if (_averageFPS >= 58) return 'Excellent';
    if (_averageFPS >= 50) return 'Good';
    if (_averageFPS >= 40) return 'Fair';
    return 'Poor';
  }

  void dispose() {
    _monitoringTimer?.cancel();
    _frameTimes.clear();
  }
}

/// Widget Rebuild Tracker - Rastreia rebuilds desnecessários
class RebuildTracker extends StatelessWidget {
  final Widget child;
  final String name;
  
  static final Map<String, int> _rebuildCounts = {};

  const RebuildTracker({
    super.key,
    required this.child,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    _rebuildCounts[name] = (_rebuildCounts[name] ?? 0) + 1;
    
    // Log se muitos rebuilds
    if (_rebuildCounts[name]! > 10) {
      debugPrint('⚠️ Widget "$name" rebuilt ${_rebuildCounts[name]} times!');
    }

    return child;
  }

  static Map<String, int> getStats() => Map.from(_rebuildCounts);
  
  static void reset() => _rebuildCounts.clear();
}

/// Optimized List - ListView otimizada
class OptimizedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ScrollController? controller;
  final EdgeInsets? padding;

  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      // Otimizações
      cacheExtent: 500, // Pre-render 500px extras
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      addSemanticIndexes: false, // Desabilitar se não precisa
    );
  }
}

/// Optimized Grid - GridView otimizada
class OptimizedGridView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets? padding;

  const OptimizedGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.crossAxisCount,
    this.mainAxisSpacing = 8.0,
    this.crossAxisSpacing = 8.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      // Otimizações
      cacheExtent: 500,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
    );
  }
}

/// Repaint Boundary Helper
class OptimizedRepaintBoundary extends StatelessWidget {
  final Widget child;

  const OptimizedRepaintBoundary({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: child,
    );
  }
}

/// Lazy Image - Carrega imagem lazy
class LazyImage extends StatefulWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const LazyImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<LazyImage> createState() => _LazyImageState();
}

class _LazyImageState extends State<LazyImage> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(widget.imagePath),
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
              // Otimizações
              cacheWidth: widget.width?.toInt(),
              cacheHeight: widget.height?.toInt(),
              filterQuality: FilterQuality.medium,
            )
          : SizedBox(
              width: widget.width,
              height: widget.height,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
    );
  }
}

/// Visibility Detector - Detecta visibilidade de widget
class VisibilityDetector extends StatefulWidget {
  final Widget child;
  final Key key;
  final void Function(VisibilityInfo) onVisibilityChanged;

  const VisibilityDetector({
    required this.key,
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

/// Throttled Builder - Limita rebuilds
class ThrottledBuilder extends StatefulWidget {
  final Widget Function(BuildContext) builder;
  final Duration throttle;

  const ThrottledBuilder({
    super.key,
    required this.builder,
    this.throttle = const Duration(milliseconds: 100),
  });

  @override
  State<ThrottledBuilder> createState() => _ThrottledBuilderState();
}

class _ThrottledBuilderState extends State<ThrottledBuilder> {
  Timer? _timer;
  bool _needsRebuild = false;

  void _scheduleRebuild() {
    if (_timer?.isActive ?? false) {
      _needsRebuild = true;
      return;
    }

    setState(() {});

    _timer = Timer(widget.throttle, () {
      if (_needsRebuild) {
        _needsRebuild = false;
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Memoized Widget - Cache de widget
class MemoizedWidget extends StatelessWidget {
  final Widget Function() builder;
  final List<Object?> dependencies;

  static final Map<String, Widget> _cache = {};

  const MemoizedWidget({
    super.key,
    required this.builder,
    this.dependencies = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cacheKey = dependencies.map((d) => d.hashCode).join('_');

    if (!_cache.containsKey(cacheKey)) {
      _cache[cacheKey] = builder();
    }

    return _cache[cacheKey]!;
  }

  static void clearCache() => _cache.clear();
}

/// Scroll Performance Monitor
class ScrollPerformanceMonitor extends StatefulWidget {
  final Widget child;
  final ScrollController controller;

  const ScrollPerformanceMonitor({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<ScrollPerformanceMonitor> createState() =>
      _ScrollPerformanceMonitorState();
}

class _ScrollPerformanceMonitorState extends State<ScrollPerformanceMonitor> {
  int _frameCount = 0;
  DateTime _lastCheck = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    _frameCount++;

    final now = DateTime.now();
    if (now.difference(_lastCheck).inSeconds >= 1) {
      final fps = _frameCount;
      debugPrint('📱 Scroll FPS: $fps');

      _frameCount = 0;
      _lastCheck = now;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }
}
