import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];
  DateTime _selectedDate = DateTime.now();
  
  // Mixed list order: "cat:CategoryName" or "task:TaskID"
  List<String> _homeDisplayOrder = [];
  
  // Settings
  bool _autoCollapseCategory = true;
  bool get autoCollapseCategory => _autoCollapseCategory;
  
  void setAutoCollapseCategory(bool value) {
    _autoCollapseCategory = value;
    _saveSettings();
    notifyListeners();
  }
  
  // Dragging state
  bool _isGlobalDragging = false;
  bool get isGlobalDragging => _isGlobalDragging;
  
  void setGlobalDragging(bool value) {
    _isGlobalDragging = value;
    notifyListeners();
  }

  // Delete Mode
  bool _isDeleteMode = false;
  bool get isDeleteMode => _isDeleteMode;

  void toggleDeleteMode() {
    _isDeleteMode = !_isDeleteMode;
    notifyListeners();
  }

  void setDeleteMode(bool value) {
    _isDeleteMode = value;
    notifyListeners();
  }

  void deleteTask(String id) {
    // Remove from tasks
    _tasks.removeWhere((t) => t.id == id);
    
    // Remove from display order
    _homeDisplayOrder.removeWhere((item) => item == "task:$id");
    
    // Clean up animation states
    _recentlyCompletedTaskIds.remove(id);
    _animatingOutTasks.removeWhere((t) => t.id == id);

    _saveTasks();
    notifyListeners();
  }

  void deleteCategory(String category) {
    // 1. Find tasks to delete to track their IDs
    final tasksToDelete = _tasks.where((t) => t.category == category).toList();
    final taskIdsToDelete = tasksToDelete.map((t) => "task:${t.id}").toSet();
    
    // 2. Remove tasks from the main list
    _tasks.removeWhere((t) => t.category == category);
    
    // 3. Remove category and its tasks from display order
    _homeDisplayOrder.removeWhere((item) => 
      item == "cat:$category" || taskIdsToDelete.contains(item)
    );

    _saveTasks();
    notifyListeners();
  }


  TaskProvider() {
    _loadTasks();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoCollapseCategory', _autoCollapseCategory);
  }


  List<Task> get tasks => _tasks;

  List<Task> getTasksForDay(DateTime date) {
    return _tasks.where((task) {
      return isSameDay(task.date, date);
    }).toList();
  }

  List<Task> get tasksForSelectedDate {
    return getTasksForDay(_selectedDate);
  }


  List<Task> get completedTasksForSelectedDate {
    return tasksForSelectedDate
        .where((task) => task.status == TaskStatus.completed)
        .toList();
  }

  DateTime get selectedDate => _selectedDate;

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void addTask(Task task) {
    _tasks.add(task);
    _saveTasks();
    notifyListeners();
  }

  // Animation state
  final Set<String> _recentlyCompletedTaskIds = {};
  // Tasks that are visually in the "pending" list but are actually completed/animating out
  final List<Task> _animatingOutTasks = [];

  bool isTaskRecentlyCompleted(String id) {
    return _recentlyCompletedTaskIds.contains(id);
  }

  void clearRecentlyCompleted(String id) {
    if (_recentlyCompletedTaskIds.remove(id)) {
      // notifyListeners(); 
    }
  }

  // Called when animation finishes in Top List
  void finishAnimation(String id) {
    _animatingOutTasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void updateTaskStatus(String id, TaskStatus status) {
    // Standard update
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      if (status == TaskStatus.completed && _tasks[index].status != TaskStatus.completed) {
         // It's a completion event.
         // Just mark recently completed for bottom list animation.
         // We don't use _animatingOutTasks here because this method is generic.
         // The specific "Simultaneous" animation is triggered by completeTaskWithAnimation.
         _recentlyCompletedTaskIds.add(id);
      } else {
        _recentlyCompletedTaskIds.remove(id);
      }

      _tasks[index] = _tasks[index].copyWith(status: status);
      _saveTasks();
      notifyListeners();
    }
  }

  // Specialized method for the Swipe-to-Complete action
  // [ghostStatus] allows overriding the status of the animating ghost.
  // For swipe: keep original (null) so it looks like the card being swiped.
  // For tap: set to completed so it "checks off" before vanishing.
  void completeTaskWithAnimation(String id, {TaskStatus? ghostStatus}) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _tasks[index];
      if (task.status != TaskStatus.completed) {
        // 1. Create Ghost
        final ghost = task.copyWith(status: ghostStatus ?? task.status);
        _animatingOutTasks.add(ghost);

        // 2. Mark for bottom animation
        _recentlyCompletedTaskIds.add(id);

        // 3. Update Real Task to completed
        _tasks[index] = task.copyWith(status: TaskStatus.completed);
        
        // 4. Save and Notify
        _saveTasks();
        notifyListeners();
      }
    }
  }

  // Import logic
  void importTasksFromText(String text) {
    final lines = text.split('\n');
    String? currentCategory;
    
    // We need to track added items to update display order
    List<String> addedTaskIds = [];
    List<String> addedCategories = [];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('。') || line.startsWith('.')) {
        String categoryContent = line.substring(1).trim();
        if (categoryContent.isEmpty) {
          currentCategory = null; // Reset category
        } else {
          currentCategory = categoryContent;
          if (!addedCategories.contains("cat:$currentCategory")) {
             addedCategories.add("cat:$currentCategory");
          }
        }
      } else {
        // It's a task
        final newTask = Task(
          title: line,
          category: currentCategory,
          date: _selectedDate, // Add to currently selected date
          status: TaskStatus.todo,
        );
        _tasks.add(newTask);
        
        // If it's uncategorized, we want to add it to the top of the list
        if (currentCategory == null) {
           addedTaskIds.add("task:${newTask.id}");
        }
      }
    }
    
    // Update Display Order
    // Uncategorized tasks go to TOP (reversed so first line is top)
    for (var taskId in addedTaskIds.reversed) {
       _homeDisplayOrder.insert(0, taskId);
    }
    
    // Categories go to BOTTOM (if new)
    for (var catId in addedCategories) {
       if (!_homeDisplayOrder.contains(catId)) {
          _homeDisplayOrder.add(catId);
       }
    }

    _saveTasks();
    notifyListeners();
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Persistence
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(
      _tasks.map((task) => task.toJson()).toList(),
    );
    await prefs.setString('tasks', encodedData);
    await prefs.setStringList('homeDisplayOrder', _homeDisplayOrder);
    
    // Backward compatibility cleanup? No, keep it simple.
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('tasks');
    if (encodedData != null) {
      final List<dynamic> decodedData = json.decode(encodedData);
      _tasks = decodedData.map((item) => Task.fromJson(item)).toList();
    }
    _homeDisplayOrder = prefs.getStringList('homeDisplayOrder') ?? [];
    
    // Load Settings
    _autoCollapseCategory = prefs.getBool('autoCollapseCategory') ?? true;
    
    notifyListeners();
  }
  
  // Get all tasks for a specific category (pending and completed)
  List<Task> getTasksForCategory(String? category) {
     final allTasks = tasksForSelectedDate;
     return allTasks.where((t) => t.category == category).toList();
  }

  // Check if a category is "Completed" (all tasks in it are completed)
  bool isCategoryCompleted(String? category) {
    final tasksInCat = tasksForSelectedDate.where((t) => t.category == category).toList();
    if (tasksInCat.isEmpty) return false;
    return tasksInCat.every((t) => t.status == TaskStatus.completed);
  }

  // --- Mixed List Logic ---
  
  // Returns a list of objects: either String (category name) or Task (uncategorized task)
  List<dynamic> get homeDisplayItems {
     final tasksOfDay = tasksForSelectedDate;
     
     // 1. Identify all valid items for today
     final Set<String> validItemIds = {};
     
     // Categories
     final categories = tasksOfDay.map((t) => t.category).whereType<String>().toSet();
     for (var c in categories) validItemIds.add("cat:$c");
     
     // Uncategorized Tasks
     final uncategorized = tasksOfDay.where((t) => t.category == null);
     for (var t in uncategorized) validItemIds.add("task:${t.id}");
     
     // 2. Reconcile with _homeDisplayOrder
     final List<dynamic> result = [];
     
     // First, existing items in order
     for (var id in _homeDisplayOrder) {
       if (validItemIds.contains(id)) {
         if (id.startsWith("cat:")) {
           result.add(id.substring(4)); // Return category name
         } else if (id.startsWith("task:")) {
           final taskId = id.substring(5);
           // Find task object
           try {
             final task = tasksOfDay.firstWhere((t) => t.id == taskId);
             result.add(task);
           } catch (e) {
             // Task might be deleted or date changed, ignore
           }
         }
         validItemIds.remove(id);
       }
     }
     
     // 3. Add new items (not in order list yet)
     final newItems = validItemIds.toList();
     final newTasks = newItems.where((i) => i.startsWith("task:")).toList();
     final newCats = newItems.where((i) => i.startsWith("cat:")).toList();
     
     // Add new tasks to top of result (User preference)
     for (var tId in newTasks) {
        final taskId = tId.substring(5);
        try {
          final task = tasksOfDay.firstWhere((t) => t.id == taskId);
          result.insert(0, task);
          _homeDisplayOrder.insert(0, tId);
        } catch (e) {}
     }
     
     // Add new categories to bottom
     for (var cId in newCats) {
        result.add(cId.substring(4));
        _homeDisplayOrder.add(cId);
     }
     
     if (newItems.isNotEmpty) {
       _saveTasks();
     }
     
     return result;
  }

  void reorderHomeItems(int oldIndex, int newIndex) {
    final currentList = homeDisplayItems; // List of String(cat) or Task
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex < 0 || oldIndex >= currentList.length) return;
    
    // Get the moved item from the VIEW list
    final item = currentList[oldIndex];
    
    // Identify its ID in _homeDisplayOrder
    String itemId;
    if (item is String) {
       itemId = "cat:$item";
    } else if (item is Task) {
       itemId = "task:${item.id}";
    } else {
       return; 
    }
    
    // We need to reorder _homeDisplayOrder based on the visible list's move
    // But _homeDisplayOrder might contain items not currently visible (other days?)
    // Actually, _homeDisplayOrder contains IDs.
    // We should reconstruct _homeDisplayOrder to match the new visual order + invisible items.
    
    // 1. Remove itemId from _homeDisplayOrder
    _homeDisplayOrder.remove(itemId);
    
    // 2. Find the insertion point.
    // The visual list is [A, B, C]. We moved A to after B -> [B, A, C].
    // In _homeDisplayOrder, we need to put A after B.
    // But what if B is not in _homeDisplayOrder (shouldn't happen)?
    // Or what if there are invisible items between A and B?
    // User wants visual order to be persisted.
    // Simpler approach: Extract all visible IDs in their NEW order.
    // Then merge with invisible IDs.
    
    // Construct new visual list
    final newVisualList = [...currentList];
    newVisualList.removeAt(oldIndex);
    newVisualList.insert(newIndex, item);
    
    final List<String> newVisualIds = newVisualList.map((i) {
       if (i is String) return "cat:$i";
       if (i is Task) return "task:${i.id}";
       return "";
    }).toList();
    
    // Filter _homeDisplayOrder to keep only invisible items
    final Set<String> visibleSet = newVisualIds.toSet();
    final invisibleItems = _homeDisplayOrder.where((id) => !visibleSet.contains(id)).toList();
    
    // Combine: NewVisual + Invisible
    // (Or should invisible be at bottom? Usually preserve relative order? 
    // Since we don't know where they were relative to visible ones easily without complex logic,
    // appending invisible at end is safest to avoid them appearing in weird spots later).
    
    _homeDisplayOrder = [...newVisualIds, ...invisibleItems];
    
    _saveTasks();
    notifyListeners();
  }
}
