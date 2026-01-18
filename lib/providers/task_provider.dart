import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';import '../models/task.dart';
import '../models/task_rule.dart';
import 'rule_provider.dart';
import '../utils/haptic_helper.dart';

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];
  DateTime _selectedDate = DateTime.now();
  
  RuleProvider? _ruleProvider;
  
  void updateRuleProvider(RuleProvider ruleProvider) {
    _ruleProvider = ruleProvider;
    // Check if we need to apply rules (e.g., if rules loaded later)
    if (_tasksLoaded) {
      _checkAndApplyDefaultRules();
    }
  }

  bool _tasksLoaded = false;

  
  // Mixed list order: "cat:CategoryName" or "task:TaskID"
  // NOW: Per-Date Display Order
  // Key: "yyyy-MM-dd", Value: List<String> of IDs
  final Map<String, List<String>> _dailyDisplayOrders = {};
  
  // Helper to get consistent date key
  String _getDateKey(DateTime date) {
    return "${date.year}-${date.month}-${date.day}";
  }

  // Helper to get current date's display order (mutable list ref)
  List<String> get _currentDisplayOrder {
    final key = _getDateKey(_selectedDate);
    if (!_dailyDisplayOrders.containsKey(key)) {
      _dailyDisplayOrders[key] = [];
    }
    return _dailyDisplayOrders[key]!;
  }
  
  // Track dates where user manually cleared tasks or wants to suppress default rules
  final Set<String> _clearedDates = {};
  
  // Track category expansion states: key=categoryName, value=isExpanded
  // Using specific string for null category if needed, but usually category is just a String key.
  // We'll use "Uncategorized" or empty string for null? 
  // Actually, Task's category is nullable String. 
  // Let's use a convention: "cat_expansion:$name"
  final Map<String, bool> _categoryExpansionStates = {};

  // Settings
  bool _autoCollapseCategory = true;
  bool get autoCollapseCategory => _autoCollapseCategory;
  
  bool _hideFutureTasksInCalendar = true;
  bool get hideFutureTasksInCalendar => _hideFutureTasksInCalendar;

  bool _vibrationEnabled = true;
  bool get vibrationEnabled => _vibrationEnabled;

  void setAutoCollapseCategory(bool value) {
    _autoCollapseCategory = value;
    _saveSettings();
    notifyListeners();
  }

  void setHideFutureTasksInCalendar(bool value) {
    _hideFutureTasksInCalendar = value;
    _saveSettings();
    notifyListeners();
  }

  void setVibrationEnabled(bool value) {
    _vibrationEnabled = value;
    HapticHelper.enabled = value;
    _saveSettings();
    notifyListeners();
  }

  bool? isCategoryExpanded(String? category) {
    final key = category ?? "__uncategorized__";
    return _categoryExpansionStates[key];
  }

  void setCategoryExpansion(String? category, bool isExpanded) {
    final key = category ?? "__uncategorized__";
    if (_categoryExpansionStates[key] != isExpanded) {
      _categoryExpansionStates[key] = isExpanded;
      _saveTasks(); // Persist along with tasks/display order
      // notifyListeners(); // Usually not needed as local widget state handles animation, but good for consistency
    }
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

  // Edit Mode
  bool _isEditMode = false;
  bool get isEditMode => _isEditMode;

  // Newly Created Task (for auto-focus)
  String? _newlyCreatedTaskId;
  String? get newlyCreatedTaskId => _newlyCreatedTaskId;

  void clearNewlyCreatedTaskId() {
    _newlyCreatedTaskId = null;
    // No need to notify listeners usually, as this is consumed by the widget
  }

  void addNewTaskToCategory(String? category) {
    // 1. Create new task with empty title
    final newTask = Task(
      title: "",
      category: category,
      date: _selectedDate,
      status: TaskStatus.todo,
    );
    
    // 2. Add to tasks list
    _tasks.add(newTask);
    
    // 3. Move to top of category
    // We need to find the index of this new task within the category view
    // Since we just added it, and getTasksForCategory preserves _tasks order,
    // it should be the last one in the category list.
    final categoryTasks = getTasksForCategory(category);
    if (categoryTasks.length > 1) {
       // Move from last position to 0
       reorderCategoryTasks(category, categoryTasks.length - 1, 0);
    }
    
    // 4. Set marker for UI to auto-focus
    _newlyCreatedTaskId = newTask.id;
    
    _saveTasks();
    notifyListeners();
  }


  // Undo Stack
  final List<DeleteOperation> _undoStack = [];
  bool get canUndo => _undoStack.isNotEmpty;

  void toggleDeleteMode() {
    _isDeleteMode = !_isDeleteMode;
    if (_isDeleteMode) {
      _isEditMode = false; // Mutually exclusive
      _undoStack.clear();
    }
    notifyListeners();
  }

  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    if (_isEditMode) {
      _isDeleteMode = false; // Mutually exclusive
    }
    notifyListeners();
  }

  void setDeleteMode(bool value) {
    _isDeleteMode = value;
    if (_isDeleteMode) {
       _isEditMode = false;
       _undoStack.clear();
    }
    notifyListeners();
  }

  void undoLastDelete() {
    if (_undoStack.isEmpty) return;
    
    final op = _undoStack.removeLast();
    final dateKey = _getDateKey(_selectedDate); // Assume undo happens on same day
    final currentOrder = _dailyDisplayOrders[dateKey] ?? [];
    if (!_dailyDisplayOrders.containsKey(dateKey)) {
        _dailyDisplayOrders[dateKey] = currentOrder;
    }
    
    if (op.type == 'task') {
      final task = op.data as Task;
      _tasks.add(task);
      
      // Restore to display order
      // We try to insert at original index, but clamp to bounds
      int insertIndex = op.originalIndex;
      if (insertIndex < 0) insertIndex = 0;
      if (insertIndex > currentOrder.length) insertIndex = currentOrder.length;
      
      currentOrder.insert(insertIndex, "task:${task.id}");
      
    } else if (op.type == 'category') {
      final backup = op.data as CategoryBackup;
      
      // Restore tasks
      _tasks.addAll(backup.tasks);
      
      // Restore category to display order
      int insertIndex = op.originalIndex;
      if (insertIndex < 0) insertIndex = 0;
      if (insertIndex > currentOrder.length) insertIndex = currentOrder.length;
      
      currentOrder.insert(insertIndex, "cat:${backup.name}");
    }
    
    _saveTasks();
    notifyListeners();
  }

  void deleteTask(String id) {
    final taskIndex = _tasks.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;
    
    final task = _tasks[taskIndex];
    final dateKey = _getDateKey(task.date);
    final currentOrder = _dailyDisplayOrders[dateKey] ?? [];

    final displayOrderIndex = currentOrder.indexOf("task:$id");
    
    // Record for undo
    _undoStack.add(DeleteOperation('task', task, displayOrderIndex));

    // Remove from tasks
    _tasks.removeAt(taskIndex);
    
    // Remove from display order
    if (displayOrderIndex != -1) {
       currentOrder.removeAt(displayOrderIndex);
    } else {
       // Should not happen for uncategorized tasks, but just in case
       currentOrder.removeWhere((item) => item == "task:$id");
    }
    
    // Clean up animation states
    _recentlyCompletedTaskIds.remove(id);
    _animatingOutTasks.removeWhere((t) => t.id == id);

    _checkIfDateCleared(task.date);

    _saveTasks();
    notifyListeners();
  }

  void deleteCategory(String category) {
    // 1. Find tasks to delete to track their IDs (ONLY for current date)
    final tasksToDelete = _tasks.where((t) => 
        t.category == category && isSameDay(t.date, _selectedDate)
    ).toList();
    
    final taskIdsToDelete = tasksToDelete.map((t) => "task:${t.id}").toSet();
    
    final currentOrder = _currentDisplayOrder;
    final displayOrderIndex = currentOrder.indexOf("cat:$category");
    
    // Record for undo
    _undoStack.add(DeleteOperation(
      'category', 
      CategoryBackup(category, tasksToDelete), 
      displayOrderIndex
    ));
    
    // 2. Remove tasks from the main list (ONLY for current date)
    _tasks.removeWhere((t) => 
        t.category == category && isSameDay(t.date, _selectedDate)
    );
    
    // 3. Remove category and its tasks from display order (ONLY for current date)
    if (displayOrderIndex != -1) {
       currentOrder.removeAt(displayOrderIndex);
    }
    currentOrder.removeWhere((item) => 
      item == "cat:$category" || taskIdsToDelete.contains(item)
    );

    _checkIfDateCleared(_selectedDate);
    
    _saveTasks();
    notifyListeners();
  }

  void _checkIfDateCleared(DateTime? date) {
    if (date == null) return;
    if (getTasksForDay(date).isEmpty) {
      final dateKey = "${date.year}-${date.month}-${date.day}";
      _clearedDates.add(dateKey);
    }
  }


  TaskProvider() {
    _loadTasks();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoCollapseCategory', _autoCollapseCategory);
    await prefs.setBool('hideFutureTasksInCalendar', _hideFutureTasksInCalendar);
    await prefs.setBool('vibrationEnabled', _vibrationEnabled);
  }


  List<Task> get tasks => _tasks;

  List<Task> getTasksForDay(DateTime date) {
    return _tasks.where((task) {
      return isSameDay(task.date, date);
    }).toList();
  }

  // Used by CalendarWidget to show dots.
  // Returns real tasks + virtual tasks if rules apply.
  List<Task> getCalendarEvents(DateTime date) {
    final realTasks = getTasksForDay(date);
    if (realTasks.isNotEmpty) {
      return realTasks;
    }

    // If no real tasks, check for rules (only for today or future)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    
    if (checkDate.isBefore(today)) {
      return [];
    }

    if (_ruleProvider != null && _ruleProvider!.hasActiveRulesForDate(date)) {
      // Return a dummy task to trigger the marker
      return [Task(title: "Virtual", date: date, status: TaskStatus.todo)];
    }
    
    return [];
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
    _checkAndApplyDefaultRules();
    notifyListeners();
  }
  
  void _checkAndApplyDefaultRules() {
    if (_ruleProvider == null) return;
    
    // Only apply if current date has NO tasks
    if (getTasksForDay(_selectedDate).isEmpty) {
      // Check date is today or future
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final checkDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      
      if (checkDate.isBefore(today)) return;

      // Check if this date was manually cleared
      final dateKey = "${checkDate.year}-${checkDate.month}-${checkDate.day}";
      if (_clearedDates.contains(dateKey)) return;

      final activeRules = _ruleProvider!.getActiveRulesForDate(_selectedDate);
      for (var rule in activeRules) {
        importTasksFromText(rule.content, sourceRuleId: rule.id);
      }
    }
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

      _tasks[index] = _tasks[index].copyWith(
        status: status,
        clearSourceRuleId: true, // User modification detaches from rule
      );
      _saveTasks();
      notifyListeners();
    }
  }

  void updateTaskTitle(String id, String newTitle) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        title: newTitle,
        clearSourceRuleId: true, // User modification detaches from rule
      );
      _saveTasks();
      notifyListeners();
    }
  }

  void updateCategoryName(String? oldName, String newName) {
    if (oldName == newName) return;

    // 1. Update tasks (Global rename still makes sense for conceptual category rename)
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].category == oldName) {
        _tasks[i] = _tasks[i].copyWith(category: newName);
      }
    }

    // 2. Update display order (In ALL dates, as this is a rename)
    final oldKeyStr = "cat:$oldName"; 
    final newKeyStr = "cat:$newName";
    
    _dailyDisplayOrders.forEach((dateKey, orderList) {
       final index = orderList.indexOf(oldKeyStr);
       if (index != -1) {
         orderList[index] = newKeyStr;
       }
    });

    // 3. Update expansion states
    // Key used in setCategoryExpansion is: category ?? "__uncategorized__"
    final oldExpKey = oldName ?? "__uncategorized__";
    final newExpKey = newName; // New name is never null here
    
    if (_categoryExpansionStates.containsKey(oldExpKey)) {
      final wasExpanded = _categoryExpansionStates[oldExpKey]!;
      _categoryExpansionStates.remove(oldExpKey);
      _categoryExpansionStates[newExpKey] = wasExpanded;
    }

    _saveTasks();
    notifyListeners();
  }

  void setTaskSteps(String id, int? steps) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final oldTask = _tasks[index];
      int newCurrentStep = 0;
      TaskStatus newStatus = oldTask.status;

      if (steps != null) {
        // If enabling/updating steps
        if (oldTask.steps != null) {
          // If already had steps, try to preserve progress
          newCurrentStep = oldTask.currentStep;
          if (newCurrentStep >= steps) {
            // If new total is less than current progress, set to n-1
            // Ensure n-1 is at least 0
            newCurrentStep = steps > 0 ? steps - 1 : 0;
          }
        } else {
          // If switching from normal task to step task, start at 0
          newCurrentStep = 0;
        }

        // If progress is less than total, ensure status is not Completed
        // (Especially when we just clamped it down from Completed)
        if (newCurrentStep < steps) {
           if (newStatus == TaskStatus.completed) {
             newStatus = TaskStatus.inProgress;
           }
        }

      } else {
        // If disabling steps, reset to 0 (normal task)
        newCurrentStep = 0;
      }

      _tasks[index] = oldTask.copyWith(
        steps: steps,
        clearSteps: steps == null,
        currentStep: newCurrentStep,
        status: newStatus,
        clearSourceRuleId: true,
      );
      _saveTasks();
      notifyListeners();
    }
  }

  void incrementTaskStep(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _tasks[index];
      if (task.steps == null) return;

      final newStep = task.currentStep + 1;
      TaskStatus newStatus = task.status;

      if (newStep >= task.steps!) {
        // Completed
        // Use completeTaskWithAnimation to get the nice effect?
        // But completeTaskWithAnimation creates a ghost.
        // If we just tap to increment, and it reaches end, maybe we want the same effect.
        // Let's check if the user wants standard completion behavior on finish.
        // "When steps become n, it will become completed state (this change is similar to animation without counting function)"
        // So yes, trigger completion.
        // However, incrementTaskStep is likely called by TAP.
        // If I call completeTaskWithAnimation, it removes the task from the list (if animating out).
        // Let's use completeTaskWithAnimation if it finishes.
        completeTaskWithAnimation(id); 
        // Note: completeTaskWithAnimation updates status to completed.
        // We also need to update currentStep to max.
        // completeTaskWithAnimation fetches the task again.
        // So we should update currentStep FIRST.
        
        _tasks[index] = task.copyWith(
            currentStep: task.steps,
            status: TaskStatus.completed, // Pre-set status so completeTaskWithAnimation sees it?
            // Actually completeTaskWithAnimation checks if status != completed.
            // So we should update currentStep but keep status as todo/inProgress, then call completeTaskWithAnimation.
        );
        // Wait, completeTaskWithAnimation creates a ghost with CURRENT status.
        // If we want the ghost to show "N/N", we should update first.
        
        // Let's just update the task here, and call completeTaskWithAnimation.
        _tasks[index] = _tasks[index].copyWith(currentStep: task.steps);
        completeTaskWithAnimation(id);
        return; 
      } else {
        newStatus = TaskStatus.inProgress;
      }

      _tasks[index] = _tasks[index].copyWith(
        currentStep: newStep,
        status: newStatus,
        clearSourceRuleId: true,
      );
      _saveTasks();
      notifyListeners();
    }
  }

  void decrementTaskStep(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _tasks[index];
      if (task.steps == null) return;

      if (task.status == TaskStatus.completed) {
        // If completed, revert to n-1
        _tasks[index] = task.copyWith(
          currentStep: task.steps! - 1,
          status: TaskStatus.inProgress,
          clearSourceRuleId: true,
        );
        _recentlyCompletedTaskIds.remove(id); // Remove from completed list if there
      } else {
        final newStep = task.currentStep - 1;
        if (newStep <= 0) {
          _tasks[index] = task.copyWith(
            currentStep: 0,
            status: TaskStatus.todo,
            clearSourceRuleId: true,
          );
        } else {
          _tasks[index] = task.copyWith(
            currentStep: newStep,
            status: TaskStatus.inProgress,
            clearSourceRuleId: true,
          );
        }
      }
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
  void importTasksFromText(String text, {String? sourceRuleId, DateTime? targetDate}) {
    final dateToUse = targetDate ?? _selectedDate;
    final lines = text.split('\n');
    String? currentCategory;
    
    // We need to track added items to update display order
    List<String> addedTaskIds = [];
    List<String> addedCategories = [];
    
    // Track if a category has actual tasks during this import
    Map<String, bool> categoryHasTasks = {};

    Task? lastAddedTask;

    for (var rawLine in lines) {
      // Check for indentation logic (steps)
      // Must start with space and be a pure number
      if (lastAddedTask != null && rawLine.startsWith(' ') && int.tryParse(rawLine.trim()) != null) {
        int steps = int.parse(rawLine.trim());
        if (steps > 0) {
          final lastTaskIndex = _tasks.indexOf(lastAddedTask);
          if (lastTaskIndex != -1) {
            final updatedTask = lastAddedTask.copyWith(
              steps: steps,
              currentStep: 0,
              status: TaskStatus.todo,
            );
            _tasks[lastTaskIndex] = updatedTask;
            lastAddedTask = updatedTask;
            continue; // Skip processing this line as a new task
          }
        }
      }

      var line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('。') || line.startsWith('.')) {
        lastAddedTask = null; // Reset last task reference on category change
        String categoryContent = line.substring(1).trim();
        if (categoryContent.isEmpty) {
          currentCategory = null; // Reset category
        } else {
          currentCategory = categoryContent;
          if (!addedCategories.contains("cat:$currentCategory")) {
             addedCategories.add("cat:$currentCategory");
             // Initialize tracking for this category
             categoryHasTasks.putIfAbsent(currentCategory, () => false);
          }
        }
      } else {
        // It's a task
        final newTask = Task(
          title: line,
          category: currentCategory,
          date: dateToUse, // Add to target date
          status: TaskStatus.todo,
          sourceRuleId: sourceRuleId,
        );
        _tasks.add(newTask);
        lastAddedTask = newTask;
        
        // Mark category as having tasks
        if (currentCategory != null) {
          categoryHasTasks[currentCategory] = true;
        }
        
        // If it's uncategorized, we want to add it to the top of the list
        if (currentCategory == null) {
           addedTaskIds.add("task:${newTask.id}");
        }
      }
    }
    
    // Check for empty categories and create placeholders
    categoryHasTasks.forEach((category, hasTasks) {
      if (!hasTasks) {
        // Create a placeholder task to keep the category alive for this day
        // but it won't be shown in the list or count towards calendar dots
        final placeholder = Task(
          title: "placeholder",
          category: category,
          date: dateToUse,
          status: TaskStatus.todo, // Status doesn't matter much as it's filtered
          isCategoryPlaceholder: true,
        );
        _tasks.add(placeholder);
      }
    });
    
    // Update Display Order (For target date)
    final dateKey = _getDateKey(dateToUse);
    if (!_dailyDisplayOrders.containsKey(dateKey)) {
        _dailyDisplayOrders[dateKey] = [];
    }
    final currentOrder = _dailyDisplayOrders[dateKey]!;

    // Uncategorized tasks go to TOP (reversed so first line is top)
    for (var taskId in addedTaskIds.reversed) {
       currentOrder.insert(0, taskId);
    }
    
    // Categories go to BOTTOM (if new)
    for (var catId in addedCategories) {
       if (!currentOrder.contains(catId)) {
          currentOrder.add(catId);
       }
    }
    
    _saveTasks();
    notifyListeners();
  }

  void forceApplyRule(TaskRule rule) {
    // 1. Remove from _clearedDates if matches
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final clearedDatesToRemove = <String>[];
    for (var dateStr in _clearedDates) {
      try {
        final parts = dateStr.split('-');
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        
        if (date.isBefore(today)) continue;
        
        // Check if date matches rule active days (1=Mon, 7=Sun)
        if (rule.activeDays.contains(date.weekday)) {
          clearedDatesToRemove.add(dateStr);
        }
      } catch (e) {
        // ignore
      }
    }
    
    _clearedDates.removeAll(clearedDatesToRemove);
    
    // 2. Retract old tasks for this rule globally (unmodified only)
    retractTasksForRule(rule.id);
    
    // 3. Apply to relevant loaded dates
    // Get all distinct dates currently in memory
    final loadedDates = _tasks.map((t) => DateTime(t.date.year, t.date.month, t.date.day)).toSet();
    
    // Also include currently selected date even if empty (so it refreshes UI)
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    loadedDates.add(selectedDay);
    
    for (var date in loadedDates) {
      if (date.isBefore(today)) continue;
      
      if (rule.activeDays.contains(date.weekday)) {
        importTasksFromText(rule.content, sourceRuleId: rule.id, targetDate: date);
      }
    }
    
    _saveTasks();
    notifyListeners();
  }

  /// Syncs the current day's tasks with the provided text.
  /// 
  /// This method:
  /// 1. Parses the text into a list of desired tasks/categories.
  /// 2. Reconciles with existing tasks:
  ///    - Updates matched tasks (title/steps).
  ///    - Creates new tasks.
  ///    - Deletes missing tasks.
  /// 3. Updates the display order to match the text.
  void syncTasksFromText(String text) {
    final lines = text.split('\n');
    
    // 1. Parse Text into a structured intermediate format
    // We use a list of items to preserve the exact order from text.
    List<dynamic> parsedItems = []; // Contains ParsedTask and CategoryHeader
    
    // Track task count per category to identify empty ones
    Map<String, int> categoryTaskCount = {};
    
    String? currentCategory;
    ParsedTask? lastParsedTask;

    for (var rawLine in lines) {
      // Check for steps (indented number)
      if (lastParsedTask != null && rawLine.startsWith(' ') && int.tryParse(rawLine.trim()) != null) {
        int steps = int.parse(rawLine.trim());
        if (steps > 0) {
          lastParsedTask.steps = steps;
          continue; 
        }
      }

      var line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('。') || line.startsWith('.')) {
        lastParsedTask = null;
        String categoryContent = line.substring(1).trim();
        if (categoryContent.isEmpty) {
          currentCategory = null; // Uncategorized
        } else {
          currentCategory = categoryContent;
          parsedItems.add(CategoryHeader(currentCategory));
          categoryTaskCount.putIfAbsent(currentCategory, () => 0);
        }
      } else {
        // Task
        final pTask = ParsedTask(
          title: line,
          category: currentCategory,
        );
        parsedItems.add(pTask);
        lastParsedTask = pTask;
        
        if (currentCategory != null) {
          categoryTaskCount[currentCategory] = (categoryTaskCount[currentCategory] ?? 0) + 1;
        }
      }
    }

    // 2. Flatten parsedItems into desiredTasks, inserting placeholders for empty categories
    List<ParsedTask> desiredTasks = [];
    
    for (var item in parsedItems) {
      if (item is ParsedTask) {
        desiredTasks.add(item);
      } else if (item is CategoryHeader) {
        // Check if this category is empty
        if ((categoryTaskCount[item.name] ?? 0) == 0) {
           // It's an empty category, add a placeholder
           desiredTasks.add(ParsedTask(
             title: "placeholder",
             category: item.name,
             isCategoryPlaceholder: true,
           ));
        }
      }
    }

    // 3. Fetch existing tasks for the day
    final existingTasks = getTasksForDay(_selectedDate);
    final List<Task> finalTasksForDay = [];
    final Set<String> usedTaskIds = {};
    
    // 4. Reconcile
    for (var pTask in desiredTasks) {
      // Try to find a match in existing tasks
      Task? match;
      try {
        if (pTask.isCategoryPlaceholder) {
           // Match placeholder
           match = existingTasks.firstWhere((t) => 
             t.category == pTask.category && 
             t.isCategoryPlaceholder &&
             !usedTaskIds.contains(t.id)
           );
        } else {
           // Match real task
           match = existingTasks.firstWhere((t) => 
             t.title == pTask.title && 
             t.category == pTask.category && 
             !t.isCategoryPlaceholder &&
             !usedTaskIds.contains(t.id)
           );
        }
      } catch (_) {}
      
      if (match != null) {
        // Update existing
        final updated = match.copyWith(
          steps: pTask.steps,
          clearSteps: pTask.steps == null,
        );
        
        // Apply steps logic manually to ensure consistency (only for real tasks)
        int newCurrentStep = updated.currentStep;
        if (!pTask.isCategoryPlaceholder) {
            if (pTask.steps != null) {
                 if (match.steps != null) {
                    if (newCurrentStep >= pTask.steps!) {
                       newCurrentStep = pTask.steps! > 0 ? pTask.steps! - 1 : 0;
                    }
                 } else {
                    newCurrentStep = 0;
                 }
            } else {
                 newCurrentStep = 0;
            }
        }
        
        final finalTask = updated.copyWith(
           currentStep: newCurrentStep,
           status: (!pTask.isCategoryPlaceholder && pTask.steps != null && newCurrentStep < pTask.steps! && updated.status == TaskStatus.completed) 
               ? TaskStatus.inProgress 
               : updated.status,
           clearSourceRuleId: true,
        );
        
        finalTasksForDay.add(finalTask);
        usedTaskIds.add(finalTask.id);
        
        // Assign ID to pTask for display order reconstruction
        pTask.assignedId = finalTask.id;
        
      } else {
        // Create new
        final newTask = Task(
          title: pTask.title,
          category: pTask.category,
          date: _selectedDate,
          status: TaskStatus.todo,
          steps: pTask.steps,
          isCategoryPlaceholder: pTask.isCategoryPlaceholder,
        );
        finalTasksForDay.add(newTask);
        // assignedId
        pTask.assignedId = newTask.id;
      }
    }
    
    // 5. Update global _tasks list
    _tasks.removeWhere((t) => isSameDay(t.date, _selectedDate));
    _tasks.addAll(finalTasksForDay);
    
    // 6. Update display order (For selected date)
    final currentOrder = _currentDisplayOrder;
    
    final oldTaskIds = existingTasks.map((t) => "task:${t.id}").toSet();
    currentOrder.removeWhere((id) => oldTaskIds.contains(id));
    
    List<String> orderedIdsFromText = [];
    Set<String> processedCategories = {};
    
    for (var task in finalTasksForDay) {
       final category = task.category;
       if (category == null) {
         // Uncategorized Task -> Always in display order
         orderedIdsFromText.add("task:${task.id}");
       } else {
         // Categorized Task (Real or Placeholder) -> Category Header in display order (ONCE)
         if (processedCategories.add(category)) {
           orderedIdsFromText.add("cat:$category");
         }
       }
    }
    
    // Remove old entries from currentOrder (categories that are being moved/re-added)
    currentOrder.removeWhere((id) => 
        orderedIdsFromText.contains(id) || 
        oldTaskIds.contains(id) 
    );
    
    // Insert new order at top
    currentOrder.insertAll(0, orderedIdsFromText);
    
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
    await prefs.setString('dailyDisplayOrders', json.encode(_dailyDisplayOrders));
    await prefs.setStringList('clearedDates', _clearedDates.toList());
    await prefs.setString('categoryExpansionStates', json.encode(_categoryExpansionStates));
    
    // Backward compatibility cleanup? No, keep it simple.
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('tasks');
    if (encodedData != null) {
      final List<dynamic> decodedData = json.decode(encodedData);
      _tasks = decodedData.map((item) => Task.fromJson(item)).toList();
    }
    
    // Load daily display orders
    final String? dailyOrdersData = prefs.getString('dailyDisplayOrders');
    if (dailyOrdersData != null) {
       try {
         final Map<String, dynamic> decoded = json.decode(dailyOrdersData);
         _dailyDisplayOrders.clear();
         decoded.forEach((key, value) {
            if (value is List) {
              _dailyDisplayOrders[key] = List<String>.from(value);
            }
         });
       } catch (e) {
         // ignore corruption
       }
    } else {
       // Migration: If we have old 'homeDisplayOrder', apply it to current day?
       // Or just discard. Discard is safer for "isolation" goal.
       // But if user has existing setup, it would be nice to keep it for at least today.
       final oldOrder = prefs.getStringList('homeDisplayOrder');
       if (oldOrder != null && oldOrder.isNotEmpty) {
           // Apply to "today" as a fallback so user doesn't lose everything immediately
           final now = DateTime.now();
           final key = _getDateKey(now);
           _dailyDisplayOrders[key] = oldOrder;
       }
    }
    
    final savedClearedDates = prefs.getStringList('clearedDates');
    if (savedClearedDates != null) {
      _clearedDates.addAll(savedClearedDates);
    }

    final expansionData = prefs.getString('categoryExpansionStates');
    if (expansionData != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(expansionData);
        decoded.forEach((key, value) {
           if (value is bool) {
             _categoryExpansionStates[key] = value;
           }
        });
      } catch (e) {
        // ignore corruption
      }
    }

    // Load Settings
    _autoCollapseCategory = prefs.getBool('autoCollapseCategory') ?? true;
    _hideFutureTasksInCalendar = prefs.getBool('hideFutureTasksInCalendar') ?? true;
    _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
    HapticHelper.enabled = _vibrationEnabled;
    
    _tasksLoaded = true;
    _checkAndApplyDefaultRules();
    notifyListeners();
  }
  
  // Get all tasks for a specific category (pending and completed)
  List<Task> getTasksForCategory(String? category) {
     final allTasks = tasksForSelectedDate;
     return allTasks.where((t) => t.category == category && !t.isCategoryPlaceholder).toList();
  }

  // Reorder tasks within a specific category
  void reorderCategoryTasks(String? category, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final categoryTasks = getTasksForCategory(category);
    
    if (oldIndex < 0 || oldIndex >= categoryTasks.length) return;
    
    final taskToMove = categoryTasks[oldIndex];
    
    // Remove from global list
    final globalOldIndex = _tasks.indexOf(taskToMove);
    if (globalOldIndex == -1) return;
    
    _tasks.removeAt(globalOldIndex);
    
    // Detach from rule on reorder
    final updatedTask = taskToMove.copyWith(clearSourceRuleId: true);
    
    // Find insertion point
    // Get remaining tasks for this category to find the reference task
    final remainingCategoryTasks = getTasksForCategory(category);
    
    if (remainingCategoryTasks.isEmpty) {
       _tasks.add(updatedTask);
    } else if (newIndex >= remainingCategoryTasks.length) {
       // Insert after the last task of this category
       final lastTask = remainingCategoryTasks.last;
       final globalIndex = _tasks.indexOf(lastTask);
       _tasks.insert(globalIndex + 1, updatedTask);
    } else {
       // Insert before the task currently at newIndex
       final targetTask = remainingCategoryTasks[newIndex];
       final globalIndex = _tasks.indexOf(targetTask);
       _tasks.insert(globalIndex, updatedTask);
    }
    
    _saveTasks();
    notifyListeners();
  }

  // Retract tasks for a specific rule (e.g., when disabled)
  // Only removes tasks that haven't been manually modified (still have sourceRuleId)
  void retractTasksForRule(String ruleId) {
    // 1. Identify tasks to remove
    final tasksToRemove = _tasks.where((t) => t.sourceRuleId == ruleId).toList();
    if (tasksToRemove.isEmpty) return;
    
    final taskIdsToRemove = tasksToRemove.map((t) => "task:${t.id}").toSet();
    
    // 2. Remove from tasks list
    _tasks.removeWhere((t) => t.sourceRuleId == ruleId);
    
    // 3. Cleanup display order
    // We iterate through all daily orders and remove the tasks
    // Since we know the tasks are being removed, we could find their dates.
    // But iterating all tasks is expensive if we do it one by one.
    // Faster: Iterate _dailyDisplayOrders and remove matching task IDs.
    
    _dailyDisplayOrders.forEach((dateKey, orderList) {
       orderList.removeWhere((item) => taskIdsToRemove.contains(item));
    });
    
    // 4. Update cleared dates
    // If removing these tasks makes a date empty, we should probably mark it as cleared?
    // Or maybe not. If I disable a rule, and the day becomes empty, it's just empty.
    // If I re-enable the rule later, I might want it to re-apply?
    // The user said "disable... retract". If I re-enable, usually it applies to future.
    // But if I re-enable and go to that date, it's empty.
    // _checkAndApplyDefaultRules checks if empty.
    // If I don't mark as cleared, re-enabling -> visiting date -> auto-apply.
    // This seems consistent.
    
    _saveTasks();
    notifyListeners();
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
     for (var c in categories) {
       validItemIds.add("cat:$c");
     }
     
     // Uncategorized Tasks
     final uncategorized = tasksOfDay.where((t) => t.category == null);
     for (var t in uncategorized) {
       validItemIds.add("task:${t.id}");
     }
     
     // 2. Reconcile with current display order
     final currentOrder = _currentDisplayOrder;
     final List<dynamic> result = [];
     
     // First, existing items in order
     for (var id in currentOrder) {
       if (validItemIds.contains(id)) {
         if (id.startsWith("cat:")) {
           result.add(id.substring(4)); // Return category name
         } else if (id.startsWith("task:")) {
           final taskId = id.substring(5);
           // Find task object
           try {
            final task = tasksOfDay.firstWhere((t) => t.id == taskId);
            result.add(task);
          } catch (_) {
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
         currentOrder.insert(0, tId);
       } catch (_) {}
    }
     
     // Add new categories to bottom
     for (var cId in newCats) {
        result.add(cId.substring(4));
        currentOrder.add(cId);
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
    
    // Identify its ID in display order
    String itemId;
    if (item is String) {
       itemId = "cat:$item";
    } else if (item is Task) {
       itemId = "task:${item.id}";
    } else {
       return; 
    }
    
    final currentOrder = _currentDisplayOrder;

    // We need to reorder currentOrder based on the visible list's move
    // But currentOrder might contain items not currently visible (other days?)
    // No, currentOrder is per-day now. It should only contain items for THIS day.
    // However, it might contain ghost IDs (deleted tasks not yet cleaned up).
    
    // 1. Remove itemId from currentOrder
    currentOrder.remove(itemId);
    
    // 2. Find the insertion point.
    // The visual list is [A, B, C]. We moved A to after B -> [B, A, C].
    // In currentOrder, we need to put A after B.
    
    // Construct new visual list
    final newVisualList = [...currentList];
    newVisualList.removeAt(oldIndex);
    newVisualList.insert(newIndex, item);
    
    final List<String> newVisualIds = newVisualList.map((i) {
       if (i is String) return "cat:$i";
       if (i is Task) return "task:${i.id}";
       return "";
    }).toList();
    
    // Filter currentOrder to keep only invisible items (ghosts?)
    final Set<String> visibleSet = newVisualIds.toSet();
    final invisibleItems = currentOrder.where((id) => !visibleSet.contains(id)).toList();
    
    // Combine: NewVisual + Invisible
    final newOrder = [...newVisualIds, ...invisibleItems];
    
    // Update the map list
    currentOrder.clear();
    currentOrder.addAll(newOrder);
    
    _saveTasks();
    notifyListeners();
  }
}

class DeleteOperation {
  final String type; // 'task' or 'category'
  final dynamic data; // Task object or CategoryBackup
  final int originalIndex; // In _homeDisplayOrder
  
  DeleteOperation(this.type, this.data, this.originalIndex);
}

class CategoryBackup {
  final String name;
  final List<Task> tasks;
  CategoryBackup(this.name, this.tasks);
}

class CategoryHeader {
  final String name;
  CategoryHeader(this.name);
}

class ParsedTask {
  String title;
  String? category;
  int? steps;
  String? assignedId;
  bool isCategoryPlaceholder;
  
  ParsedTask({
    required this.title, 
    this.category, 
    this.steps,
    this.isCategoryPlaceholder = false,
  });
}
