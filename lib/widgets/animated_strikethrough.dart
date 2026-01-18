import 'package:flutter/material.dart';

class AnimatedStrikethrough extends StatefulWidget {
  final Widget child;
  final bool active;
  final Color color;
  final double thickness;
  final Duration duration;
  final Curve curve;

  const AnimatedStrikethrough({
    super.key,
    required this.child,
    required this.active,
    this.color = Colors.black,
    this.thickness = 2.0,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });

  @override
  State<AnimatedStrikethrough> createState() => _AnimatedStrikethroughState();
}

class _AnimatedStrikethroughState extends State<AnimatedStrikethrough>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);

    if (widget.active) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedStrikethrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _StrikethroughPainter(
                    progress: _animation.value,
                    color: widget.color,
                    thickness: widget.thickness,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StrikethroughPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double thickness;

  _StrikethroughPainter({
    required this.progress,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6) // Slightly transparent like a pen
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round // Rounded ends like a marker
      ..style = PaintingStyle.stroke;

    final startY = size.height / 2;
    final endX = size.width * progress;

    // Draw a simple line for now. 
    // Ideally, for "handwritten" look, we might want slight curve or imperfection,
    // but a straight line with rounded caps and opacity is a good start for "Apple style".
    canvas.drawLine(
      Offset(0, startY),
      Offset(endX, startY),
      paint,
    );
  }

  @override
  bool shouldRepaint(_StrikethroughPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.thickness != thickness;
  }
}
