import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/task_item.dart';
import '../widgets/category_card.dart';
import '../widgets/text_input_sheet.dart';
import '../widgets/deletable_item_wrapper.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const CalendarWidget(),
          Expanded(
            child: Consumer<TaskProvider>(
              builder: (context, taskProvider, child) {
                // Get mixed list of items
                final homeItems = taskProvider.homeDisplayItems;
                
                if (homeItems.isEmpty) {
                  return Center(
                    child: Text(
                      '没有任务',
                      style: AppTheme.bodySmall,
                    ),
                  );
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.only(top: 16, bottom: 80),
                  itemCount: homeItems.length,
                  proxyDecorator: (child, index, animation) {
                     // Customize drag appearance
                     return AnimatedBuilder(
                       animation: animation,
                       builder: (context, child) {
                         final double animValue = Curves.easeInOut.transform(animation.value);
                         final double elevation = lerpDouble(0, 6, animValue)!;
                         return Material(
                           elevation: elevation,
                          color: Colors.transparent,
                          shadowColor: Colors.black.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          child: child,
                         );
                       },
                       child: child,
                     );
                  },
                  onReorderStart: (index) {
                     HapticHelper.selection();
                     taskProvider.setGlobalDragging(true);
                  },
                  onReorderEnd: (index) {
                     taskProvider.setGlobalDragging(false);
                  },
                  onReorder: (oldIndex, newIndex) {
                    taskProvider.reorderHomeItems(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final item = homeItems[index];
                    final isDeleteMode = taskProvider.isDeleteMode;
                    
                    if (item is String) {
                      // It's a Category
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey("cat:$item"),
                        index: index,
                        child: CategoryCard(
                          category: item,
                          isDeleteMode: isDeleteMode,
                        ),
                      );
                    } else if (item is Task) {
                      // It's an Uncategorized Task
                      // We wrap it to look consistent and handle drag
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey("task:${item.id}"),
                        index: index,
                        child: DeletableItemWrapper(
                          isDeleteMode: isDeleteMode,
                          onDelete: () => taskProvider.deleteTask(item.id),
                          child: TaskItem(
                            task: item,
                            showCategory: false, // It's uncategorized
                            isRoot: true, // Use root styling (larger radius, correct margin)
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink(key: ValueKey("unknown"));
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add_task, color: Colors.white),
        onPressed: () {
          HapticHelper.heavy();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const TextInputSheet(),
          );
        },
      ),
    );
  }
  
  double? lerpDouble(num? a, num? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}
