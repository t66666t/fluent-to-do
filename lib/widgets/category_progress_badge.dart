import 'dart:math' as math;
import 'dart:ui' as ui;
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
  late AnimationController _gradientController;
  late AnimationController _ratioController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkScaleAnimation;
  bool _wasAllDone = false;
  List<String> _depthOrder = const [];
  final Map<String, double> _depthFrom = {};
  final Map<String, double> _depthTo = {};
  int _depthSignature = 0;
  double _inProgressFrom = 0.0;
  double _inProgressTo = 0.0;
  double _completedFrom = 0.0;
  double _completedTo = 0.0;

  // New Color Palette
  static const Color _todoColor = Color(0xFFF2F2F7); // iOS System Gray 6
  static const Color _inProgressColor = Color(0xFF54C7FC); // iOS System Teal Blue
  static const Color _doneColor = Color(0xFF34C759); // iOS System Green

  static final Color _stepLightBlue = Color.lerp(_inProgressColor, Colors.white, 0.55)!;

  double _taskStepDepth(Task task) {
    final steps = task.steps;
    if (steps == null) return 1.0;
    if (steps <= 1) return 1.0;
    return (task.currentStep / (steps - 1)).clamp(0.0, 1.0).toDouble();
  }

  LinearGradient _buildInProgressGradient({
    required List<String> order,
    required Map<String, double> depths,
  }) {
    if (order.isEmpty) {
      return LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [_inProgressColor, _inProgressColor],
      );
    }

    final count = order.length;
    final colors = <Color>[];
    final stops = <double>[];

    for (var i = 0; i < count; i++) {
      final id = order[i];
      final depth = (depths[id] ?? 0.0).clamp(0.0, 1.0).toDouble();
      final bandStart = i / count;
      final bandEnd = (i + 1) / count;
      final deepColor = Color.lerp(_stepLightBlue, _inProgressColor, depth)!;
      colors.add(deepColor);
      stops.add(bandStart);
      colors.add(deepColor);
      stops.add(bandEnd);
    }

    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: colors,
      stops: stops,
    );
  }

  int _computeDepthSignature(List<Task> nonTodoTasks) {
    var hash = nonTodoTasks.length;
    for (final task in nonTodoTasks) {
      hash = 31 * hash + task.id.hashCode;
      hash = 31 * hash + (_taskStepDepth(task) * 1000).round();
    }
    return hash;
  }

  void _syncStepDepths({required bool animate}) {
    final nonTodoTasks =
        widget.tasks.where((t) => t.status != TaskStatus.todo).toList(growable: false);

    final signature = _computeDepthSignature(nonTodoTasks);
    if (signature == _depthSignature) return;

    final t = Curves.easeOutCubic.transform(_gradientController.value);

    final nextOrder = nonTodoTasks.map((t) => t.id).toList(growable: false);
    final nextDepths = <String, double>{
      for (final task in nonTodoTasks) task.id: _taskStepDepth(task),
    };

    final ids = <String>{
      ..._depthFrom.keys,
      ..._depthTo.keys,
      ...nextDepths.keys,
    };

    for (final id in ids) {
      final from = _depthFrom[id] ?? _depthTo[id] ?? nextDepths[id] ?? 0.0;
      final to = _depthTo[id] ?? nextDepths[id] ?? from;
      final current = ui.lerpDouble(from, to, t) ?? to;
      _depthFrom[id] = current;
      _depthTo[id] = nextDepths[id] ?? 0.0;
    }

    _depthOrder = nextOrder;
    _depthSignature = signature;

    if (animate) {
      _gradientController.forward(from: 0.0);
    } else {
      _gradientController.value = 1.0;
    }
  }

  void _syncRatios({required bool animate}) {
    final total = widget.tasks.length;
    final completed = widget.tasks.where((t) => t.status == TaskStatus.completed).length;
    final inProgress = widget.tasks.where((t) => t.status == TaskStatus.inProgress).length;

    final targetInProgress = total == 0 ? 0.0 : (completed + inProgress) / total;
    final targetCompleted = total == 0 ? 0.0 : completed / total;

    final t = Curves.easeOutCubic.transform(_ratioController.value);
    final currentInProgress = ui.lerpDouble(_inProgressFrom, _inProgressTo, t) ?? _inProgressTo;
    final currentCompleted = ui.lerpDouble(_completedFrom, _completedTo, t) ?? _completedTo;

    final sameInProgress = (targetInProgress - _inProgressTo).abs() <= 0.0001;
    final sameCompleted = (targetCompleted - _completedTo).abs() <= 0.0001;
    if (sameInProgress && sameCompleted) return;

    _inProgressFrom = currentInProgress;
    _inProgressTo = targetInProgress.clamp(0.0, 1.0).toDouble();
    _completedFrom = currentCompleted;
    _completedTo = targetCompleted.clamp(0.0, 1.0).toDouble();

    if (animate) {
      _ratioController.forward(from: 0.0);
    } else {
      _ratioController.value = 1.0;
    }
  }

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
    
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );

    _ratioController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1.0,
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
    _syncStepDepths(animate: false);
    _syncRatios(animate: false);
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
    _syncStepDepths(animate: true);
    _syncRatios(animate: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    _celebrationController.dispose();
    _gradientController.dispose();
    _ratioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) return const SizedBox.shrink();

    final total = widget.tasks.length;
    final isAllDone =
        widget.tasks.isNotEmpty && widget.tasks.every((t) => t.status == TaskStatus.completed);

    return AnimatedBuilder(
      animation: Listenable.merge(
        [_waveController, _celebrationController, _gradientController, _ratioController],
      ),
      builder: (context, child) {
        final ratioT = Curves.easeOutCubic.transform(_ratioController.value);
        final inProgressRatio =
            (ui.lerpDouble(_inProgressFrom, _inProgressTo, ratioT) ?? _inProgressTo)
                .clamp(0.0, 1.0)
                .toDouble();
        var completedRatio =
            (ui.lerpDouble(_completedFrom, _completedTo, ratioT) ?? _completedTo)
                .clamp(0.0, 1.0)
                .toDouble();
        if (completedRatio > inProgressRatio) {
          completedRatio = inProgressRatio;
        }

        final textT = ((inProgressRatio - 0.30) / 0.25).clamp(0.0, 1.0).toDouble();
        final textColor = Color.lerp(Colors.black54, Colors.white, textT)!;
        final shadowAlpha = (0.26 * textT).clamp(0.0, 0.26).toDouble();

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
                Builder(
                  builder: (context) {
                    final t = Curves.easeOutCubic.transform(_gradientController.value);
                    final animatedDepths = <String, double>{};
                    for (final id in _depthOrder) {
                      final from = _depthFrom[id] ?? _depthTo[id] ?? 0.0;
                      final to = _depthTo[id] ?? from;
                      animatedDepths[id] = ui.lerpDouble(from, to, t) ?? to;
                    }

                    final rank = <String, int>{
                      for (var i = 0; i < _depthOrder.length; i++) _depthOrder[i]: i,
                    };
                    final order = [..._depthOrder];
                    order.sort((a, b) {
                      final da = animatedDepths[a] ?? 0.0;
                      final db = animatedDepths[b] ?? 0.0;
                      final diff = db - da;
                      if (diff.abs() < 0.06) {
                        return (rank[a] ?? 0).compareTo(rank[b] ?? 0);
                      }
                      return db.compareTo(da);
                    });

                    final gradient = _buildInProgressGradient(
                      order: order,
                      depths: animatedDepths,
                    );

                    return CustomPaint(
                      size: const Size(32, 32),
                      painter: _WavePainter(
                        animationValue: _waveController.value,
                        progress: inProgressRatio,
                        color: _inProgressColor,
                        gradient: gradient,
                        phaseOffset: 0,
                        waveHeight: 1.0,
                      ),
                    );
                  },
                ),

                // Layer 2: Completed (Green Water)
                // Same phase as Blue so they move together without mixing weirdly
                CustomPaint(
                  size: const Size(32, 32),
                  painter: _WavePainter(
                    animationValue: _waveController.value,
                    progress: completedRatio,
                    color: _doneColor,
                    phaseOffset: 0,
                    waveHeight: 1.0,
                  ),
                ),

                // Content: Number or Checkmark
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: isAllDone && _checkScaleAnimation.value > 0.1
                        ? Transform.scale(
                            key: const ValueKey('check'),
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
                        : Text(
                            "$total",
                            key: ValueKey('count_$total'),
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              shadows: shadowAlpha <= 0.01
                                  ? null
                                  : [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: shadowAlpha),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      )
                                    ],
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
  final Gradient? gradient;
  final double phaseOffset;
  final double waveHeight;

  _WavePainter({
    required this.animationValue,
    required this.progress,
    required this.color,
    this.gradient,
    this.phaseOffset = 0,
    this.waveHeight = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return; // Optimization

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

    final Paint paint = Paint()..style = PaintingStyle.fill;
    if (gradient != null) {
      paint.shader = gradient!.createShader(
        Rect.fromLTWH(0, baseHeight, size.width, size.height - baseHeight),
      );
    } else {
      paint.color = color;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.gradient != gradient;
  }
}
