import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';
import 'task_item.dart';
import 'animated_strikethrough.dart';

class CategoryCard extends StatefulWidget {
  final String? category; // null means "Uncategorized"
  final bool isCompleted; // Whether the entire category is "done"

  const CategoryCard({
    super.key,
    required this.category,
    this.isCompleted = false,
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

  const _CategoryCardContent({
    required this.category,
    required this.tasks,
    required this.isCategoryDone,
    required this.headerColor,
    required this.titleStyle,
    required this.isGlobalDragging,
    required this.autoCollapse,
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
    
    // Initial state check
    // If autoCollapse is ON and category is done, start collapsed.
    // If autoCollapse is OFF, we might want to default to expanded? 
    // Or just keep it expanded unless user closed it?
    // Current logic: if done, collapse.
    // Adjusted logic: if done AND autoCollapse, collapse.
    if (widget.isCategoryDone && widget.autoCollapse) {
       _isExpanded = false;
       _controller.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(_CategoryCardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    
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
           _toggleExpansion();
        }
      } else {
        // Drag Ended: Restore state
        // If it was expanded before drag, expand it back.
        // UNLESS it became done during drag? Unlikely.
        if (_wasExpandedBeforeDrag && !_isExpanded && !widget.isCategoryDone) {
           _toggleExpansion();
        }
      }
    }
  }

  void _toggleExpansion() {
    HapticHelper.medium();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              InkWell(
                onTap: _toggleExpansion,
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
                        child: AnimatedStrikethrough(
                          active: widget.isCategoryDone,
                          color: widget.headerColor,
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: widget.titleStyle,
                            child: Text(
                              widget.category ?? "未分类",
                            ),
                          ),
                        ),
                      ),
                      // Task Count Badge
                      if (widget.tasks.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${widget.tasks.length}",
                            style: AppTheme.bodySmall.copyWith(fontSize: 12),
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
                          child: Column(
                            children: widget.tasks.map((task) {
                              return Padding(
                                key: ValueKey(task.id),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: TaskItem(
                                  task: task,
                                  showCategory: false,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
  }
}
