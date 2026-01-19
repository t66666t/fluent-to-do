import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';
import 'animated_strikethrough.dart';
import 'scale_button.dart';
import 'step_wheel_picker.dart';

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
  static const double _completeThreshold = 30.0; // Right swipe threshold
  static const double _inProgressThreshold = 20.0; // Left swipe threshold

  // Completion "Pop" Animation
  late AnimationController _completionController;
  late Animation<double> _completionScaleAnimation;

  // Haptic feedback state
  bool _hasVibratedComplete = false;
  bool _hasVibratedInProgress = false;

  // Edit Mode
  late TextEditingController _textController;
  late FocusNode _focusNode;
  bool _isEditingText = false;

  // Step Counter Configuration
  bool _isConfiguringSteps = false;
  int _tempSteps = 1;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.task.title);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);

    _controller = AnimationController.unbounded(vsync: this);
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

    final provider = Provider.of<TaskProvider>(context, listen: false);
    bool isNewTask = provider.newlyCreatedTaskId == widget.task.id;

    if (widget.animateEntry) {
      _runEntranceAnimation();
    } else if (isNewTask) {
       // New task animation: Expand height
       _heightController.value = 0.0;
       _heightController.forward();
    }
    
    // Check for auto-focus on new task
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isNewTask) {
         setState(() {
            _isEditingText = true;
         });
         _focusNode.requestFocus();
         provider.clearNewlyCreatedTaskId();
      }
    });
  }

  void _runEntranceAnimation() {
    // Start from left (-1.0) and move to center (0.0)
    _mode = AnimationMode.slide;
    _isSimulation = false;
    _animation = Tween<Offset>(
      begin: const Offset(-0.8, 0.0), // Don't start too far out
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)); // Smoother, no overshoot
    
    _controller.animateTo(1.0, duration: const Duration(milliseconds: 350)).then((_) {
      if (mounted) {
         Provider.of<TaskProvider>(context, listen: false)
             .clearRecentlyCompleted(widget.task.id);
      }
    });
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditingText) {
       _saveTitle();
    }
  }

  void _saveTitle() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      if (text != widget.task.title) {
        Provider.of<TaskProvider>(context, listen: false)
            .updateTaskTitle(widget.task.id, text);
      }
    } else {
      // If empty:
      // 1. If it was a new task (empty title originally), delete it (Undo/Cancel creation)
      // 2. If it was an existing task, revert to old title
      if (widget.task.title.isEmpty) {
         Provider.of<TaskProvider>(context, listen: false)
             .deleteTask(widget.task.id);
      } else {
         _textController.text = widget.task.title; // Revert if empty
      }
    }
    if (mounted) {
      setState(() {
        _isEditingText = false;
      });
    }
  }

  @override
  void didUpdateWidget(TaskItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.task.title != oldWidget.task.title && !_isEditingText) {
      _textController.text = widget.task.title;
    }

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
        // Don't reset _isConfiguringSteps here unless we want to close it on update?
        // Maybe keep it open if just status changed?
        // If ID changed, we should reset.
        // The checks above call _reset() on ID change.
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _heightController.dispose();
    _completionController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Helper to check if we are running simulation
  bool _isSimulation = false;

  void _runSpringBack([double velocity = 0.0]) {
    _isSimulation = true;
    _mode = AnimationMode.slide;
    // A nice bouncy spring for return
    // Adjusted for "silky" feel with Apple-style parameters
    final simulation = SpringSimulation(
      const SpringDescription(
        mass: 1.0, 
        stiffness: 200.0, 
        damping: 25.0, 
      ),
      _dragExtent, // Start position (pixels)
      0.0, // End position (pixels)
      velocity, // Initial velocity
      tolerance: const Tolerance(distance: 0.01, velocity: 0.01),
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

  void _runPulse() {
    setState(() {
      _mode = AnimationMode.pulse;
    });
    _controller.stop();
    _controller.value = 0.0;
    _controller.animateTo(1.0, duration: const Duration(milliseconds: 300)).then((_) {
      if (mounted) {
        setState(() {
           _mode = AnimationMode.none;
           _controller.value = 0.0;
        });
      }
    });
  }

  void _showEditStepDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _tempSteps.toString());
        return AlertDialog(
          title: const Text('Set Steps'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final val = int.tryParse(controller.text);
                if (val != null && val > 0) {
                  setState(() {
                    _tempSteps = val;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isEditMode = context.watch<TaskProvider>().isEditMode;

    // Intercept Back Button if configuring
    // PopScope is available in newer Flutter. If strict requirement is compatibility, check version.
    // Env says 3.8.1 SDK, so PopScope is fine.
    return PopScope(
      canPop: !_isConfiguringSteps,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isConfiguringSteps) {
          setState(() {
            _isConfiguringSteps = false;
          });
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double currentOffset = _dragExtent;
          double opacity = 1.0;
          double scale = 1.0;
          
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
             if (_isSimulation) {
                currentOffset = _controller.value;
             } else if (_mode == AnimationMode.slide) {
               currentOffset = _animation.value.dx * size.width;
             }
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
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
                          _dragExtent = currentOffset;
                          _mode = AnimationMode.slide;
                        });
                      },
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          double delta = details.primaryDelta!;
                          if (_dragExtent + delta < 0) {
                             delta *= 0.5; 
                          }
                          _dragExtent += delta;

                          // Haptic feedback logic
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
                        
                        // RIGHT SWIPE Logic
                        if (_dragExtent > _completeThreshold) {
                          if (!_hasVibratedComplete) HapticHelper.medium();
                          
                          // Toggle Configuration Mode
                          if (_isConfiguringSteps) {
                             setState(() { _isConfiguringSteps = false; });
                          } else {
                             setState(() {
                               _isConfiguringSteps = true;
                               _tempSteps = widget.task.steps ?? 1;
                             });
                          }
                          _runSpringBack(details.primaryVelocity ?? 0.0);

                        } else if (_dragExtent < -_inProgressThreshold) {
                          // LEFT SWIPE Logic
                          if (!_hasVibratedInProgress) HapticHelper.selection();
                          
                          if (widget.task.steps != null) {
                             // Decrement Step
                             Provider.of<TaskProvider>(context, listen: false)
                                .decrementTaskStep(widget.task.id);
                          } else {
                             // Standard Logic
                             final newStatus = widget.task.status == TaskStatus.inProgress
                                 ? TaskStatus.todo
                                 : TaskStatus.inProgress;
                             Provider.of<TaskProvider>(context, listen: false)
                                 .updateTaskStatus(widget.task.id, newStatus);
                          }
                          
                          _runSpringBack(details.primaryVelocity ?? 0.0);
                        } else {
                          _runSpringBack(details.primaryVelocity ?? 0.0);
                        }
                      },
                      onTap: () {
                         if (isEditMode) {
                            HapticHelper.selection();
                            setState(() {
                               _isEditingText = true;
                            });
                            _focusNode.requestFocus();
                            return;
                         }
                         
                         // If configuring steps, maybe close? Or ignore?
                         // User says "Click cancel button or Swipe Right again or Back key".
                         // Doesn't say Tap closes it. I'll leave it open on tap.
                         if (_isConfiguringSteps) return;

                         if (widget.task.steps != null) {
                            // Step Logic
                            HapticHelper.selection();
                            Provider.of<TaskProvider>(context, listen: false)
                                .incrementTaskStep(widget.task.id);
                            return;
                         }

                         // Standard Logic
                         if (widget.task.status == TaskStatus.todo) {
                            HapticHelper.selection();
                            Provider.of<TaskProvider>(context, listen: false)
                               .updateTaskStatus(widget.task.id, TaskStatus.inProgress);
                         } else if (widget.task.status == TaskStatus.inProgress) {
                            HapticHelper.heavy();
                            Provider.of<TaskProvider>(context, listen: false)
                               .updateTaskStatus(widget.task.id, TaskStatus.completed);
                            _completionController.forward(from: 0.0);
                         } else {
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
      ),
    );
  }

  Widget _buildCardContent({TaskStatus? overrideStatus}) {
    final currentStatus = overrideStatus ?? widget.task.status;
    
    return SizeTransition(
      sizeFactor: _heightAnimation,
      axisAlignment: 0.0,
      child: Container(
        margin: widget.isRoot 
             ? const EdgeInsets.only(bottom: 12, left: 16, right: 16)
             : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(widget.isRoot ? 16 : 12),
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _isEditingText
                        ? TextField(
                            key: const ValueKey('editing'),
                            controller: _textController,
                            focusNode: _focusNode,
                            onSubmitted: (_) => _saveTitle(),
                            onTapOutside: (_) => _saveTitle(),
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textPrimary,
                              decoration: TextDecoration.none,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                          )
                        : Row(
                              key: const ValueKey('text'),
                              mainAxisSize: MainAxisSize.min, // Use min size to wrap text tightly
                              children: [
                                Flexible( // Allow wrapping if needed, but here we want strikethrough to fit text width
                                  child: AnimatedStrikethrough(
                                    active: currentStatus == TaskStatus.completed,
                                    color: AppTheme.textSecondary,
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: currentStatus == TaskStatus.completed
                                            ? AppTheme.textSecondary
                                            : AppTheme.textPrimary,
                                        decoration: TextDecoration.none,
                                      ),
                                      child: Text(
                                        widget.task.title,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
            
            // Step Counter UI
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic, // Smoother expansion
              switchOutCurve: Curves.easeInCubic, // Smoother collapse
              transitionBuilder: (Widget child, Animation<double> animation) {
                // Combine Slide and Fade for "Apple-style" reveal
                return ClipRect(
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0), // Slide from right
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axis: Axis.horizontal,
                        axisAlignment: -1.0, // Anchor left, expand right
                        child: child,
                      ),
                    ),
                  ),
                );
              },
              child: _isConfiguringSteps
                  ? SizedBox(
                      height: 32, // Enforce fixed height to match badge
                      child: _buildStepConfigRow(),
                    )
                  : (widget.task.steps != null
                      ? SizedBox(
                          height: 32, // Enforce fixed height
                          child: _buildStepBadge(),
                        )
                      : const SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConfigRow() {
    return Container(
      key: const ValueKey('config_row'),
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.textSecondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Step Wheel Picker (iOS Style)
          StepWheelPicker(
            initialValue: _tempSteps,
            onChanged: (newValue) {
              setState(() {
                _tempSteps = newValue;
              });
            },
          ),
          // 2. Edit Button
          ScaleButton(
            onTap: _showEditStepDialog,
            child: _buildCompactIconButtonContent(
              icon: Icons.edit_rounded,
              color: AppTheme.textSecondary,
            ),
          ),
          // 3. Confirm Button
          ScaleButton(
            onTap: () {
              Provider.of<TaskProvider>(context, listen: false)
                  .setTaskSteps(widget.task.id, _tempSteps);
              setState(() {
                _isConfiguringSteps = false;
              });
              HapticHelper.medium();
            },
            child: _buildCompactIconButtonContent(
              icon: Icons.check_rounded,
              color: AppTheme.successColor,
            ),
          ),
          // 4. Cancel Button
          ScaleButton(
            onTap: () {
              setState(() {
                _isConfiguringSteps = false;
              });
              HapticHelper.light();
            },
            child: _buildCompactIconButtonContent(
              icon: Icons.close_rounded,
              color: AppTheme.errorColor,
            ),
          ),
          // 5. Disable Button
          ScaleButton(
            onTap: () {
              Provider.of<TaskProvider>(context, listen: false)
                  .setTaskSteps(widget.task.id, null);
              setState(() {
                _isConfiguringSteps = false;
              });
              HapticHelper.medium();
            },
            child: _buildCompactIconButtonContent(
              icon: Icons.remove_circle_outline_rounded,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactIconButtonContent({
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Icon(
        icon,
        size: 18,
        color: color,
      ),
    );
  }

  Widget _buildStepBadge() {
    return Padding(
      key: const ValueKey('step_badge'),
      padding: const EdgeInsets.only(left: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: Text(
            '${widget.task.currentStep}',
            key: ValueKey<int>(widget.task.currentStep),
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget for scale tap effect
  // ignore: unused_element
  Widget _buildCompactIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    // Legacy support, redirected to new structure if used elsewhere
    return ScaleButton(
      onTap: onPressed,
      child: _buildCompactIconButtonContent(icon: icon, color: color),
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

    return ScaleTransition(
      scale: status == TaskStatus.completed 
          ? _completionScaleAnimation 
          : const AlwaysStoppedAnimation(1.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
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
