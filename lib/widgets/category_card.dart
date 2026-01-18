import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';
import 'task_item.dart';
import 'animated_strikethrough.dart';
import 'category_progress_badge.dart';
import 'deletable_item_wrapper.dart';

class CategoryCard extends StatefulWidget {
  final String? category; // null means "Uncategorized"
  final bool isCompleted; // Whether the entire category is "done"
  final bool isDeleteMode;

  const CategoryCard({
    super.key,
    required this.category,
    this.isCompleted = false,
    this.isDeleteMode = false,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  @override
  Widget build(BuildContext context) {
    // We rebuild when tasks change
    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        final tasks = provider.getTasksForCategory(widget.category);
        final isCategoryDone = tasks.isNotEmpty && tasks.every((t) => t.status == TaskStatus.completed);
        
        // Style changes if done
        final headerColor = isCategoryDone 
            ? AppTheme.textSecondary.withValues(alpha: 0.5) 
            : AppTheme.textPrimary;
            
        final titleStyle = AppTheme.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: headerColor,
          decoration: TextDecoration.none, // Custom strikethrough
        );

        return _CategoryCardContent(
           category: widget.category,
           tasks: tasks,
           isCategoryDone: isCategoryDone,
           headerColor: headerColor,
           titleStyle: titleStyle,
           isGlobalDragging: provider.isGlobalDragging,
           autoCollapse: provider.autoCollapseCategory,
           isDeleteMode: widget.isDeleteMode,
           isEditMode: provider.isEditMode,
        );
      },
    );
  }
}

class _CategoryCardContent extends StatefulWidget {
  final String? category;
  final List<Task> tasks;
  final bool isCategoryDone;
  final Color headerColor;
  final TextStyle titleStyle;
  final bool isGlobalDragging;
  final bool autoCollapse;
  final bool isDeleteMode;
  final bool isEditMode;

  const _CategoryCardContent({
    required this.category,
    required this.tasks,
    required this.isCategoryDone,
    required this.headerColor,
    required this.titleStyle,
    required this.isGlobalDragging,
    required this.autoCollapse,
    required this.isDeleteMode,
    required this.isEditMode,
  });

  @override
  State<_CategoryCardContent> createState() => _CategoryCardContentState();
}

class _CategoryCardContentState extends State<_CategoryCardContent> with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  bool _wasExpandedBeforeDrag = true;
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  // Delete Animation
  late AnimationController _deleteController;
  late Animation<double> _deleteScaleAnimation;
  late Animation<double> _deleteFadeAnimation;
  late Animation<double> _deleteSizeAnimation;

  // Edit Mode
  late TextEditingController _textController;
  late FocusNode _focusNode;
  bool _isEditingText = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: 1.0, 
    );
    _iconTurns = Tween<double>(begin: 0.0, end: 0.25).animate(_controller);
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeIn));

    // Delete Animation Setup
    _deleteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 0.0,
    );
    _deleteScaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _deleteController, curve: Curves.easeOutCubic),
    );
    _deleteFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _deleteController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _deleteSizeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _deleteController, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );

    // Edit Mode Setup
    _textController = TextEditingController(text: widget.category ?? "未分类");
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    
    // Initial state check
    final provider = Provider.of<TaskProvider>(context, listen: false);
    final persistedState = provider.isCategoryExpanded(widget.category);
    
    if (persistedState != null) {
       _isExpanded = persistedState;
    } else {
       // If autoCollapse is ON and category is done, start collapsed.
       if (widget.isCategoryDone && widget.autoCollapse) {
          _isExpanded = false;
       } else {
          _isExpanded = true;
       }
    }
    
    if (!_isExpanded) {
       _controller.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(_CategoryCardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update text controller if category changes externally
    if (widget.category != oldWidget.category) {
      if (!_isEditingText) {
        _textController.text = widget.category ?? "未分类";
      }
    }

    // Auto-exit text editing if global edit mode is turned off
    if (!widget.isEditMode && oldWidget.isEditMode) {
      if (_isEditingText) {
        _saveCategoryName();
      }
    }

    // Auto-collapse logic from status change
    // Only if autoCollapse is true
    if (widget.autoCollapse) {
      if (!oldWidget.isCategoryDone && widget.isCategoryDone) {
         if (_isExpanded) _toggleExpansion();
      } else if (oldWidget.isCategoryDone && !widget.isCategoryDone) {
         // Auto-expand when new incomplete tasks added (or status changed back)
         if (!_isExpanded) _toggleExpansion();
      }
    }
    
    // Global Drag Logic
    if (widget.isGlobalDragging != oldWidget.isGlobalDragging) {
      if (widget.isGlobalDragging) {
        // Drag Started: Save state and collapse
        _wasExpandedBeforeDrag = _isExpanded;
        if (_isExpanded) {
           _toggleExpansion(save: false); // Don't save temp state
        }
      } else {
        // Drag Ended: Restore state
        // If it was expanded before drag, expand it back.
        // UNLESS it became done during drag? Unlikely.
        if (_wasExpandedBeforeDrag && !_isExpanded && !widget.isCategoryDone) {
           _toggleExpansion(save: false); // Don't save temp state
        }
      }
    }
  }

  void _toggleExpansion({bool save = true}) {
    HapticHelper.medium();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    
    if (save) {
      Provider.of<TaskProvider>(context, listen: false)
        .setCategoryExpansion(widget.category, _isExpanded);
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditingText) {
      _saveCategoryName();
    }
  }

  void _saveCategoryName() {
    final newName = _textController.text.trim();
    final oldName = widget.category;
    
    // Check if changed
    // Note: widget.category can be null (Uncategorized).
    // If text is "未分类" (default for null), and widget.category is null, no change.
    // If text is "Something" and widget.category is null, changed.
    final currentDisplayName = oldName ?? "未分类";
    
    if (newName.isNotEmpty && newName != currentDisplayName) {
       Provider.of<TaskProvider>(context, listen: false)
           .updateCategoryName(oldName, newName);
    } else if (newName.isEmpty) {
      _textController.text = currentDisplayName; // Revert
    }

    if (mounted) {
      setState(() {
        _isEditingText = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _deleteController.dispose();
    _textController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteCategory() async {
    if (_deleteController.isAnimating || _deleteController.isCompleted) return;
    HapticHelper.medium();
    await _deleteController.forward();
    if (mounted && widget.category != null) {
      Provider.of<TaskProvider>(context, listen: false)
          .deleteCategory(widget.category!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _deleteController,
      builder: (context, child) {
         return SizeTransition(
           sizeFactor: _deleteSizeAnimation,
           axisAlignment: 0.0,
           child: FadeTransition(
             opacity: _deleteFadeAnimation,
             child: ScaleTransition(
               scale: _deleteScaleAnimation,
               child: child,
             ),
           ),
         );
      },
      child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.03),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Stack(
                children: [
                  // 1. Visual Header (Inactive for taps in delete mode via IgnorePointer, or handled below)
                  // We use the existing InkWell but disable it in delete mode visually or functionally
                  IgnorePointer(
                    ignoring: widget.isDeleteMode,
                    child: InkWell(
                      onTap: () {
                        if (widget.isEditMode) {
                          if (_isEditingText) return;
                          setState(() {
                             _isEditingText = true;
                          });
                          _textController.text = widget.category ?? "未分类";
                          _focusNode.requestFocus();
                          HapticHelper.medium();
                        } else {
                          _toggleExpansion();
                        }
                      },
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16), bottom: Radius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          children: [
                            // Category Icon/Indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: widget.isCategoryDone ? AppTheme.successColor.withValues(alpha: 0.2) : AppTheme.primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOutBack,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Icon(
                                  widget.isCategoryDone ? Icons.check : (widget.category == null ? Icons.inbox : Icons.folder),
                                  key: ValueKey(widget.isCategoryDone),
                                  size: 14,
                                  color: widget.isCategoryDone ? AppTheme.successColor : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                                  return Stack(
                                    alignment: Alignment.centerLeft,
                                    children: <Widget>[
                                      ...previousChildren,
                                      if (currentChild != null) currentChild,
                                    ],
                                  );
                                },
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    axis: Axis.horizontal,
                                    axisAlignment: -1.0,
                                    child: child,
                                  ),
                                ),
                                child: _isEditingText
                                    ? TextField(
                                        controller: _textController,
                                        focusNode: _focusNode,
                                        style: widget.titleStyle.copyWith(decoration: TextDecoration.none),
                                        textAlign: TextAlign.start,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onSubmitted: (_) => _saveCategoryName(),
                                      )
                                    : AnimatedStrikethrough(
                                        active: widget.isCategoryDone,
                                        color: widget.headerColor,
                                        child: AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 200),
                                          style: widget.titleStyle,
                                          textAlign: TextAlign.start,
                                          child: Text(
                                            widget.category ?? "未分类",
                                            textAlign: TextAlign.start,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            // Task Count Badge
                            CategoryProgressBadge(tasks: widget.tasks),
                            const SizedBox(width: 8),
                            
                            // Add Task Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  if (widget.isDeleteMode) return;
                                  HapticHelper.selection();
                                  // Add task
                                  Provider.of<TaskProvider>(context, listen: false)
                                      .addNewTaskToCategory(widget.category);
      
                                  // Ensure expanded
                                  if (!_isExpanded) {
                                    _toggleExpansion();
                                  }
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            RotationTransition(
                              turns: _iconTurns,
                              child: const Icon(Icons.chevron_right, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Delete Mode Overlay & Interaction
                  if (widget.isDeleteMode)
                    Positioned.fill(
                      child: Row(
                        children: [
                          // Left Half: Delete Category
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _handleDeleteCategory,
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                          // Right Half: Toggle Expansion
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _toggleExpansion,
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                  // 3. Delete Badge (Visual) - Removed

                ],
              ),
              
              // Body
              ClipRect(
                child: AnimatedBuilder(
                  animation: _controller.view,
                  builder: (BuildContext context, Widget? child) {
                    return Align(
                      heightFactor: _heightFactor.value,
                      child: child,
                    );
                  },
                  child: widget.tasks.isEmpty 
                      ? const SizedBox.shrink()
                      : Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              proxyDecorator: (child, index, animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (BuildContext context, Widget? child) {
                                    final double animValue = Curves.easeInOut.transform(animation.value);
                                    final double elevation = lerpDouble(0, 6, animValue)!;
                                    final double scale = lerpDouble(1, 1.02, animValue)!;
                                    return Transform.scale(
                                      scale: scale,
                                      child: Material(
                                        elevation: elevation,
                                        color: Colors.transparent,
                                        shadowColor: Colors.black.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: child,
                                );
                              },
                              onReorder: (oldIndex, newIndex) {
                                Provider.of<TaskProvider>(context, listen: false)
                                    .reorderCategoryTasks(widget.category, oldIndex, newIndex);
                              },
                              children: widget.tasks.map((task) {
                                final item = Padding(
                                  key: ValueKey(task.id),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: TaskItem(
                                    task: task,
                                    showCategory: false,
                                  ),
                                );

                                if (widget.isDeleteMode) {
                                  return DeletableItemWrapper(
                                    key: ValueKey("del_${task.id}"),
                                    isDeleteMode: true,
                                    onDelete: () => Provider.of<TaskProvider>(
                                            context,
                                            listen: false)
                                        .deleteTask(task.id),
                                    child: item,
                                  );
                                }
                                return item;
                              }).toList(),
                          ),
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }

  // Badge removed

}
