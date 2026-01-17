import 'package:flutter/material.dart';
import '../utils/haptic_helper.dart';
import '../theme/app_theme.dart';

class DeletableItemWrapper extends StatefulWidget {
  final Widget child;
  final bool isDeleteMode;
  final VoidCallback onDelete;

  const DeletableItemWrapper({
    super.key,
    required this.child,
    required this.isDeleteMode,
    required this.onDelete,
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
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
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
          IgnorePointer(
            ignoring: widget.isDeleteMode,
            child: widget.child,
          ),

          // Delete Mode Overlay & Interaction
          if (widget.isDeleteMode)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleDelete,
                child: Container(
                  color: Colors.transparent, // Hit test target
                  child: Stack(
                    children: [
                      // Visual indicator: Shake or badge
                      // We place a small badge to the left of the content
                      // Assuming content has ~16px left margin
                      Positioned(
                        left: 4,
                        top: 12, // Align with header text roughly
                        child: _buildDeleteBadge(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeleteBadge() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: AppTheme.errorColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.remove,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }
}
