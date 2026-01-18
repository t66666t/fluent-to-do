import 'package:flutter/material.dart';
import '../utils/haptic_helper.dart';


class DeletableItemWrapper extends StatefulWidget {
  final Widget child;
  final bool isDeleteMode;
  final VoidCallback onDelete;
  final bool enableSplitTap;
  final bool disableInteraction;

  const DeletableItemWrapper({
    super.key,
    required this.child,
    required this.isDeleteMode,
    required this.onDelete,
    this.enableSplitTap = false,
    this.disableInteraction = false,
  });

  @override
  State<DeletableItemWrapper> createState() => _DeletableItemWrapperState();
}

class _DeletableItemWrapperState extends State<DeletableItemWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _sizeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 0.0,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _sizeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    if (_controller.isAnimating || _controller.isCompleted) return;

    // Haptic feedback
    HapticHelper.medium();

    // Play animation
    await _controller.forward();
    
    // Perform delete
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: _sizeAnimation,
          axisAlignment: 0.0,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: child,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          // Content
          // We use IgnorePointer to disable interaction with the card content in delete mode
          // unless split tap is enabled (then we only ignore left side via overlay)
          IgnorePointer(
            ignoring: widget.isDeleteMode && !widget.enableSplitTap,
            child: widget.child,
          ),

          // Delete Mode Overlay & Interaction
          if (widget.isDeleteMode && !widget.disableInteraction)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Interaction Zone
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: widget.enableSplitTap ? constraints.maxWidth * 0.5 : constraints.maxWidth,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleDelete,
                          child: Container(
                            color: Colors.transparent, // Hit test target
                          ),
                        ),
                      ),
                      
                      // Badge removed

                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Badge removed

}
