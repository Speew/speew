import 'package:flutter/material.dart';

/// Typing Indicator Widget
/// Shows animated dots when someone is typing
class TypingIndicator extends StatefulWidget {
  final Color? color;
  final double size;

  const TypingIndicator({
    super.key,
    this.color,
    this.size = 8.0,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animations = List.generate(3, (index) {
      return TweenSequence<double>([
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
          parent: _controller,
          curve: Interval(
            index * 0.2,
            1.0,
            curve: Curves.linear,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? Colors.grey;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * 0.3),
              child: Opacity(
                opacity: 0.3 + (_animations[index].value * 0.7),
                child: Transform.translate(
                  offset: Offset(0, -widget.size * 0.5 * _animations[index].value),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: dotColor,
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

/// Typing Indicator Bubble
/// Shows "User is typing..." message
class TypingIndicatorBubble extends StatelessWidget {
  final String userName;

  const TypingIndicatorBubble({
    super.key,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$userName está digitando',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            const TypingIndicator(size: 6),
          ],
        ),
      ),
    );
  }
}
