import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';

class CategoryProgressBadge extends StatefulWidget {
  final List<Task> tasks;

  const CategoryProgressBadge({
    super.key,
    required this.tasks,
  });

  @override
  State<CategoryProgressBadge> createState() => _CategoryProgressBadgeState();
}

class _CategoryProgressBadgeState extends State<CategoryProgressBadge> with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _celebrationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkScaleAnimation;
  bool _wasAllDone = false;

  // New Color Palette
  static const Color _todoColor = Color(0xFFF2F2F7); // iOS System Gray 6
  static const Color _inProgressColor = Color(0xFF54C7FC); // iOS System Teal Blue
  static const Color _doneColor = Color(0xFF34C759); // iOS System Green

  @override
  void initState() {
    super.initState();
    
    // Wave Animation (Infinite Loop) - Slowed down for relaxation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000), // Slower speed
    )..repeat();

    // Celebration Animation (One-shot)
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Bounce Scale for Container
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOutQuad)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
    ]).animate(_celebrationController);

    // Checkmark Scale (Delayed)
    _checkScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _celebrationController,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _checkInitialStatus();
  }

  void _checkInitialStatus() {
    if (widget.tasks.isNotEmpty && widget.tasks.every((t) => t.status == TaskStatus.completed)) {
      _wasAllDone = true;
      // Ensure the checkmark is visible immediately if already done
      _celebrationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(CategoryProgressBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final isAllDone = widget.tasks.isNotEmpty && widget.tasks.every((t) => t.status == TaskStatus.completed);
    
    if (isAllDone && !_wasAllDone) {
      // Transition to Done -> Trigger Celebration
      _celebrationController.forward(from: 0.0);
      HapticHelper.heavy();
    } else if (!isAllDone && _wasAllDone) {
      // Reset if no longer done
      _celebrationController.reset();
    }
    
    _wasAllDone = isAllDone;
  }

  @override
  void dispose() {
    _waveController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) return const SizedBox.shrink();

    final total = widget.tasks.length;
    final completed = widget.tasks.where((t) => t.status == TaskStatus.completed).length;
    final inProgress = widget.tasks.where((t) => t.status == TaskStatus.inProgress).length;
    
    // Calculate Ratios
    final double inProgressRatio = total == 0 ? 0 : (completed + inProgress) / total;
    final double completedRatio = total == 0 ? 0 : completed / total;
    
    final isAllDone = completedRatio >= 1.0;

    // Text Color Logic:
    // If water is low (< 50%), use Dark Text.
    // If water is high (> 50%), use White Text.
    final useWhiteText = inProgressRatio > 0.4;

    return AnimatedBuilder(
      animation: Listenable.merge([_waveController, _celebrationController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 32, 
            height: 32,
            decoration: BoxDecoration(
              color: _todoColor,
              shape: BoxShape.circle,
              boxShadow: [
                 BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                 )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Layer 1: In Progress (Blue Water)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: inProgressRatio),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack, // Q-Bouncy transition for water level
                  builder: (context, value, child) {
                    return CustomPaint(
                      size: const Size(32, 32),
                      painter: _WavePainter(
                        animationValue: _waveController.value,
                        progress: value,
                        color: _inProgressColor,
                        phaseOffset: 0, // Sync phase
                        waveHeight: 1.0, 
                      ),
                    );
                  },
                ),

                // Layer 2: Completed (Green Water)
                // Same phase as Blue so they move together without mixing weirdly
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: completedRatio),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack, // Q-Bouncy transition for water level
                  builder: (context, value, child) {
                    return CustomPaint(
                      size: const Size(32, 32),
                      painter: _WavePainter(
                        animationValue: _waveController.value,
                        progress: value,
                        color: _doneColor,
                        phaseOffset: 0, // Sync phase with blue layer
                        waveHeight: 1.0, // Same wave height
                      ),
                    );
                  },
                ),

                // Content: Number or Checkmark
                Center(
                  child: isAllDone && _checkScaleAnimation.value > 0.1
                      ? Transform.scale(
                          scale: _checkScaleAnimation.value,
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              )
                            ],
                          ),
                        )
                      : AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isAllDone ? 0.0 : 1.0,
                          child: Text(
                            "$total",
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: useWhiteText ? Colors.white : Colors.black54,
                              shadows: useWhiteText ? [
                                const Shadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                )
                              ] : null,
                            ),
                          ),
                        ),
                ),
                
                // Flash/Highlight Effect when done
                if (isAllDone)
                   Container(
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       gradient: RadialGradient(
                         colors: [
                           Colors.white.withValues(alpha: 0.3 * (1 - _celebrationController.value)),
                           Colors.transparent
                         ],
                       ),
                     ),
                   ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final double progress;
  final Color color;
  final double phaseOffset;
  final double waveHeight;

  _WavePainter({
    required this.animationValue,
    required this.progress,
    required this.color,
    this.phaseOffset = 0,
    this.waveHeight = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return; // Optimization

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    final double baseHeight = size.height * (1 - progress);

    path.moveTo(0, baseHeight);

    // Dynamic damping: 
    // At progress 0.5 -> 1.0
    // At progress 0.0 or 1.0 -> 0.0
    // Formula: sin(progress * pi)
    // This ensures smooth tapering at both ends.
    final damping = math.sin(progress * math.pi); 
    // Or if we want more wave in the middle range:
    // final damping = (1.0 - (2 * progress - 1).abs());

    for (double x = 0; x <= size.width; x++) {
      final double y = baseHeight + 
          waveHeight * damping * math.sin((x / size.width * 2 * math.pi) + (animationValue * 2 * math.pi) + phaseOffset);
      
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}
