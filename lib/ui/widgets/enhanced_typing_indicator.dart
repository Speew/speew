import 'package:flutter/material.dart';

/// Enhanced Typing Indicator Widget
/// Multiple styles and customization options
class EnhancedTypingIndicator extends StatefulWidget {
  final TypingIndicatorStyle style;
  final Color? color;
  final double size;
  final Duration animationDuration;

  const EnhancedTypingIndicator({
    super.key,
    this.style = TypingIndicatorStyle.dots,
    this.color,
    this.size = 8.0,
    this.animationDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<EnhancedTypingIndicator> createState() => _EnhancedTypingIndicatorState();
}

class _EnhancedTypingIndicatorState extends State<EnhancedTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.style) {
      case TypingIndicatorStyle.dots:
        return _DotsIndicator(
          controller: _controller,
          color: widget.color ?? Colors.grey,
          size: widget.size,
        );
      case TypingIndicatorStyle.pulse:
        return _PulseIndicator(
          controller: _controller,
          color: widget.color ?? Colors.grey,
          size: widget.size,
        );
      case TypingIndicatorStyle.wave:
        return _WaveIndicator(
          controller: _controller,
          color: widget.color ?? Colors.grey,
          size: widget.size,
        );
    }
  }
}

enum TypingIndicatorStyle { dots, pulse, wave }

/// Dots style (WhatsApp-like)
class _DotsIndicator extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double size;

  const _DotsIndicator({
    required this.controller,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final animation = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 50.0,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 0.0)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 50.0,
          ),
        ]).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              index * 0.2,
              1.0,
              curve: Curves.linear,
            ),
          ),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.3),
              child: Opacity(
                opacity: 0.3 + (animation.value * 0.7),
                child: Transform.translate(
                  offset: Offset(0, -size * 0.5 * animation.value),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Pulse style
class _PulseIndicator extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double size;

  const _PulseIndicator({
    required this.controller,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 0.5 + (controller.value * 0.5);
        final opacity = 1.0 - controller.value;

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size * 2,
              height: size * 2,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wave style
class _WaveIndicator extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double size;

  const _WaveIndicator({
    required this.controller,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final animation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              index * 0.1,
              0.5 + (index * 0.1),
              curve: Curves.easeInOut,
            ),
          ),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final height = size + (animation.value * size * 2);
            
            return Container(
              width: size * 0.5,
              height: height,
              margin: EdgeInsets.symmetric(horizontal: size * 0.2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.3 + (animation.value * 0.7)),
                borderRadius: BorderRadius.circular(size * 0.25),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Typing Indicator Bubble with multiple names support
class EnhancedTypingBubble extends StatelessWidget {
  final List<String> typingPeers;
  final TypingIndicatorStyle style;
  final Color? bubbleColor;
  final Color? textColor;
  final Color? indicatorColor;

  const EnhancedTypingBubble({
    super.key,
    required this.typingPeers,
    this.style = TypingIndicatorStyle.dots,
    this.bubbleColor,
    this.textColor,
    this.indicatorColor,
  });

  String _getTypingText() {
    if (typingPeers.isEmpty) return '';
    
    if (typingPeers.length == 1) {
      return '${typingPeers[0]} está digitando';
    } else if (typingPeers.length == 2) {
      return '${typingPeers[0]} e ${typingPeers[1]} estão digitando';
    } else {
      return '${typingPeers.length} pessoas estão digitando';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (typingPeers.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleColor ?? (isDark ? Colors.grey[800] : Colors.grey[300]),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: const Text(
                _getTypingText(),
                style: TextStyle(
                  color: textColor ?? (isDark ? Colors.grey[300] : Colors.grey[700]),
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            EnhancedTypingIndicator(
              style: style,
              size: 6,
              color: indicatorColor ?? (isDark ? Colors.grey[500] : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact typing indicator (for chat list)
class CompactTypingIndicator extends StatelessWidget {
  final bool isTyping;
  final TypingIndicatorStyle style;

  const CompactTypingIndicator({
    super.key,
    required this.isTyping,
    this.style = TypingIndicatorStyle.dots,
  });

  @override
  Widget build(BuildContext context) {
    if (!isTyping) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EnhancedTypingIndicator(
          style: style,
          size: 4,
          color: Colors.grey,
        ),
        const SizedBox(width: 4),
        const Text(
          'digitando...',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
