import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';
import 'animated_strikethrough.dart';

enum AnimationMode { slide, vanish, pulse, none }

class TaskItem extends StatefulWidget {
  final Task task;
  final bool animateEntry;
  final bool showCategory;
  final bool isRoot; // New param for root-level styling

  const TaskItem({
    super.key, 
    required this.task, 
    this.animateEntry = false,
    this.showCategory = true,
    this.isRoot = false, // Default false
  });

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _heightController;
  late Animation<Offset> _animation;
  late Animation<double> _heightAnimation;

  double _dragExtent = 0.0;
  bool _isDragging = false;
  
  // Animation Mode
  AnimationMode _mode = AnimationMode.none;
  
  // Configuration
  static const double _completeThreshold = 60.0; // Right swipe threshold (reduced)
  static const double _inProgressThreshold = 20.0; // Left swipe threshold (reduced for sensitivity)
  
  // Completion "Pop" Animation
  late AnimationController _completionController;
  late Animation<double> _completionScaleAnimation;
  bool _skipColorAnimation = false;

  // Haptic feedback state
  bool _hasVibratedComplete = false;
  bool _hasVibratedInProgress = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _heightController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 300),
      value: 1.0, // Start fully visible
    );
    
    // Controller for the green checkmark "pop" effect
    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    // Scale sequence: 1.0 -> 1.5 -> 1.0
    _completionScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _completionController, curve: Curves.easeOutCubic));

    _animation = _controller.drive(Tween<Offset>(begin: Offset.zero, end: Offset.zero));
    _heightAnimation = CurvedAnimation(parent: _heightController, curve: Curves.easeInOut);

    if (widget.animateEntry) {
      _runEntranceAnimation();
    }
  }

  void _runEntranceAnimation() {
    // Start from left (-1.0) and move to center (0.0)
    _mode = AnimationMode.slide;
    _isSimulation = false;
    _controller.duration = const Duration(milliseconds: 350); // Slightly faster
    _animation = Tween<Offset>(
      begin: const Offset(-0.8, 0.0), // Don't start too far out
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)); // Smoother, no overshoot
    
    _controller.forward().then((_) {
      if (mounted) {
         Provider.of<TaskProvider>(context, listen: false)
             .clearRecentlyCompleted(widget.task.id);
      }
    });
  }

  @override
  void didUpdateWidget(TaskItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the task changes or its status changes (e.g. moved to completed list),
    // we must reset the swipe state to prevent "stuck" cards.
    if (widget.task.id != oldWidget.task.id) {
       _reset();
    } else if (widget.task.status != oldWidget.task.status) {
       // Status changed.
       
       // If we are vanishing OR sliding (flyout/spring), DO NOT RESET, let animation finish.
       if (_mode != AnimationMode.vanish && _mode != AnimationMode.slide) {
          _reset();
          
          // Trigger Pulse if:
          // 1. Todo -> InProgress
          // 2. InProgress -> Completed
          if ((oldWidget.task.status == TaskStatus.todo && widget.task.status == TaskStatus.inProgress) ||
              (oldWidget.task.status == TaskStatus.inProgress && widget.task.status == TaskStatus.completed)) {
             _runPulse();
          }
       }
    }
  }
  
  void _reset() {
      _controller.stop();
      _controller.value = 0.0; // Reset animation
      _heightController.value = 1.0; 
      
      setState(() {
        _dragExtent = 0.0;
        _isDragging = false;
        _isSimulation = false;
        _mode = AnimationMode.none;
        _hasVibratedComplete = false;
        _hasVibratedInProgress = false;
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _heightController.dispose();
    _completionController.dispose();
    super.dispose();
  }

  // Helper to check if we are running simulation
  bool _isSimulation = false;

  void _runSpringBack() {
    _isSimulation = true;
    _mode = AnimationMode.slide;
    // A nice bouncy spring for return
    // Adjusted for "silky" feel (lower stiffness, moderate damping)
    final simulation = SpringSimulation(
      const SpringDescription(
        mass: 1.0, 
        stiffness: 120.0, // Softer spring
        damping: 20.0, // Increased damping to prevent oscillation/jitter at end
      ),
      _dragExtent, // Start position (pixels)
      0.0, // End position (pixels)
      0.0, // Initial velocity
      tolerance: const Tolerance(distance: 0.01, velocity: 0.01), // Tighter tolerance
    );

    _controller.animateWith(simulation).whenCompleteOrCancel(() {
      if (mounted) {
        setState(() {
          _dragExtent = 0.0;
          _isSimulation = false;
        });
      }
    });
  }

  void _runFlyOut(bool toRight) {
    _isSimulation = false;
    _mode = AnimationMode.slide;
    
    _controller.stop();
    // Speed up the flyout slightly
    _controller.duration = const Duration(milliseconds: 300);
    
    // Gap between the two "trains"
    const double gap = 24.0; 
    
    // We want to slide until the incoming card (which is at left - (width + gap)) reaches 0.
    // So we need to move the main card to (width + gap).
    // The width here is the context width, but we should probably use the widget width.
    // Since we are inside a full-width list item (mostly), context.size.width works.
    final targetOffset = context.size!.width + gap;
    
    // Current offset (pixels)
    final startOffset = _dragExtent;

    // We animate from current pixel offset to target pixel offset.
    // NOTE: Tween<Offset> usually takes relative values (0.0 - 1.0).
    // BUT we are using pixel values in our Transform in build().
    // So we need to normalize if we use the same Tween logic.
    // Currently build() uses:
    // if (_mode == AnimationMode.slide) currentOffset = _animation.value.dx * size.width;
    // So _animation.value.dx should be relative.
    
    _animation = Tween<Offset>(
      begin: Offset(startOffset / context.size!.width, 0.0),
      end: Offset(targetOffset / context.size!.width, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    
    // Start flyout
    _controller.forward().then((_) async {
       if (mounted && toRight) {
          // Animation done. 
          // At this point, the "Incoming" card is at 0.0.
          // The "Outgoing" card is at targetOffset (offscreen).
          
          // FLAG ON: Prevent color transition animation on the main card
          _skipColorAnimation = true;
          
          // We immediately swap the state.
          // Reset drag extent to 0 so the "Incoming" card (which becomes the main card) stays at 0.
          
          Provider.of<TaskProvider>(context, listen: false)
             .updateTaskStatus(widget.task.id, TaskStatus.completed);
             
          // We need to reset the animation controller without triggering a reverse animation
          _controller.value = 0.0;
          _dragExtent = 0.0;
          _mode = AnimationMode.none;
          
          // Trigger the "Pop" effect
          _completionController.forward(from: 0.0);
          HapticHelper.light(); // Secondary satisfaction click
          
          setState(() {});
          
          // FLAG OFF: Re-enable color animation for future interactions
          WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) _skipColorAnimation = false;
          });
       }
    });

    // DO NOT collapse height.
  }
  
  void _runVanish() {
    setState(() {
      _mode = AnimationMode.vanish;
    });
    
    // Configure animations
    _controller.stop();
    _controller.duration = const Duration(milliseconds: 300); 
    
    _controller.forward().then((_) {
       if (mounted) {
         // Reset mode so it renders normally as completed
         setState(() {
            _mode = AnimationMode.none;
            _controller.value = 0.0;
         });
       }
    });

    // Trigger state change. 
    Provider.of<TaskProvider>(context, listen: false)
        .updateTaskStatus(widget.task.id, TaskStatus.completed);
  }
  
  void _runPulse() {
    setState(() {
      _mode = AnimationMode.pulse;
    });
    _controller.stop();
    _controller.duration = const Duration(milliseconds: 300);
    _controller.forward().then((_) {
      if (mounted) {
        setState(() {
           _mode = AnimationMode.none;
           _controller.value = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double currentOffset = _dragExtent;
        double opacity = 1.0;
        double scale = 1.0;
        
        // Calculate properties based on mode
        if (_mode == AnimationMode.vanish) {
           opacity = 1.0; 
           scale = 1.0 - (_controller.value * 0.05);
        } else if (_mode == AnimationMode.pulse) {
           double val = _controller.value;
           if (val < 0.5) {
              scale = 1.0 + (val * 0.04);
           } else {
              scale = 1.02 - ((val - 0.5) * 0.04);
           }
           currentOffset = 0.0;
        } else if (!_isDragging && _controller.isAnimating) {
           // Slide / Flyout
           if (_isSimulation) {
              currentOffset = _controller.value;
           } else if (_mode == AnimationMode.slide) {
             currentOffset = _animation.value.dx * size.width;
           }
        }
        
        // "Two Trains" Logic
        // We disabled the "Two Trains" visual for right swipe to match the requested "Spring Back" style.
        // The code below is kept commented out in case we want to revert to "Fly Out" style later.
        
        /*
        // Calculate the gap and width for the incoming card
        // We use the full width for simplicity, matching the main card
        const double gap = 24.0;
        final double cardWidth = size.width; 
        */

        return Stack(
          clipBehavior: Clip.none,
          children: [
            /*
            // The "Incoming" Card (Train B)
            // Only visible if we are dragging right or animating right
            if (currentOffset > 0)
              Positioned(
                // It follows the main card with a gap
                left: currentOffset - (cardWidth + gap),
                top: 0,
                bottom: 0,
                width: cardWidth,
                child: _buildCardContent(overrideStatus: TaskStatus.completed),
              ),
            */

            // The "Outgoing" Card (Train A - Main Content)
            Transform.translate(
              offset: Offset(currentOffset, 0),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: GestureDetector(
                    onHorizontalDragStart: (details) {
                      _controller.stop();
                      setState(() {
                        _isDragging = true;
                        _dragExtent = currentOffset; // Continue from where we are
                        _mode = AnimationMode.slide; // Force slide mode
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        double delta = details.primaryDelta!;
                        if (_dragExtent + delta < 0) {
                           delta *= 0.5; 
                        }
                        _dragExtent += delta;

                        // Haptic feedback logic for thresholds
                        if (_dragExtent > _completeThreshold && !_hasVibratedComplete) {
                           HapticHelper.medium();
                           _hasVibratedComplete = true;
                        } else if (_dragExtent <= _completeThreshold && _hasVibratedComplete) {
                           _hasVibratedComplete = false;
                        }

                        if (_dragExtent < -_inProgressThreshold && !_hasVibratedInProgress) {
                           HapticHelper.selection();
                           _hasVibratedInProgress = true;
                        } else if (_dragExtent >= -_inProgressThreshold && _hasVibratedInProgress) {
                           _hasVibratedInProgress = false;
                        }
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      setState(() {
                        _isDragging = false;
                        _hasVibratedComplete = false;
                        _hasVibratedInProgress = false;
                      });
                      
                      if (_dragExtent > _completeThreshold) {
                        // Already vibrated in update, but double check if we missed it (fast swipe)
                        if (!_hasVibratedComplete) {
                           HapticHelper.medium();
                        }
                        // OLD: _runFlyOut(true);
                        // NEW: Imitate left swipe (Spring Back)
                        
                        Provider.of<TaskProvider>(context, listen: false)
                             .updateTaskStatus(widget.task.id, TaskStatus.completed);
                         
                        // Trigger Pop effect for satisfaction
                        _completionController.forward(from: 0.0);
                         
                        _runSpringBack();

                      } else if (_dragExtent < -_inProgressThreshold) {
                        // Already vibrated in update
                        if (!_hasVibratedInProgress) {
                           HapticHelper.selection();
                        }
                        
                        final newStatus = widget.task.status == TaskStatus.inProgress
                            ? TaskStatus.todo
                            : TaskStatus.inProgress;

                        Provider.of<TaskProvider>(context, listen: false)
                            .updateTaskStatus(widget.task.id, newStatus);
                        
                        _runSpringBack();
                      } else {
                        _runSpringBack();
                      }
                    },
                    onTap: () {
                       if (widget.task.status == TaskStatus.todo) {
                          // Todo -> InProgress
                          HapticHelper.selection();
                          Provider.of<TaskProvider>(context, listen: false)
                             .updateTaskStatus(widget.task.id, TaskStatus.inProgress);
                       } else if (widget.task.status == TaskStatus.inProgress) {
                          // InProgress -> Completed
                          HapticHelper.heavy();
                          
                          // Use simple status update, which triggers Pulse via didUpdateWidget
                          Provider.of<TaskProvider>(context, listen: false)
                             .updateTaskStatus(widget.task.id, TaskStatus.completed);
                             
                          // Also trigger the "Pop" checkmark effect for extra satisfaction
                          _completionController.forward(from: 0.0);
                       } else {
                          // Completed -> Todo (Restore)
                          HapticHelper.selection();
                          Provider.of<TaskProvider>(context, listen: false)
                             .updateTaskStatus(widget.task.id, TaskStatus.todo);
                       }
                    },
                    child: _buildCardContent(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCardContent({TaskStatus? overrideStatus}) {
    // Use the override status if provided, otherwise use current task status
    final currentStatus = overrideStatus ?? widget.task.status;
    
    return SizeTransition(
      sizeFactor: _heightAnimation,
      axisAlignment: 0.0,
      child: Container(
        // Reduced margin and padding for a more compact look
        // If isRoot, match CategoryCard margin (bottom 12, horizontal 16)
        // If not isRoot (inside category), use compact vertical (4)
        margin: widget.isRoot 
             ? const EdgeInsets.only(bottom: 12, left: 16, right: 16)
             : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(widget.isRoot ? 16 : 12), // Root: 16, Inner: 12
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Wrapper to ensure alignment with CategoryCard (24x24 icon)
            SizedBox(
               width: 24, 
               height: 24,
               child: Center(
                  child: _buildStatusIndicator(currentStatus),
               ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedStrikethrough(
                    active: currentStatus == TaskStatus.completed,
                    color: AppTheme.textSecondary,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: AppTheme.bodyMedium.copyWith(
                        color: currentStatus == TaskStatus.completed
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        decoration: TextDecoration.none, // We use custom strikethrough
                      ),
                      child: Text(
                        widget.task.title,
                      ),
                    ),
                  ),
                  if (widget.showCategory && widget.task.category != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.task.category!,
                        style: AppTheme.bodySmall.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(TaskStatus status) {
    Color color;
    switch (status) {
      case TaskStatus.todo:
        color = AppTheme.textSecondary.withValues(alpha: 0.3);
        break;
      case TaskStatus.inProgress:
        color = AppTheme.primaryColor;
        break;
      case TaskStatus.completed:
        color = AppTheme.successColor;
        break;
    }

    // Use ScaleTransition for the pop effect
    return ScaleTransition(
      scale: status == TaskStatus.completed 
          ? _completionScaleAnimation 
          : const AlwaysStoppedAnimation(1.0),
      child: AnimatedContainer(
        duration: _skipColorAnimation ? Duration.zero : const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
