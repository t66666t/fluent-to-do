import 'package:uuid/uuid.dart';

enum TaskStatus {
  todo,
  inProgress,
  completed,
}

class Task {
  final String id;
  final String title;
  final String? category;
  TaskStatus status;
  final DateTime date;
  final DateTime createdAt;
  final bool isCategoryPlaceholder;
  final String? sourceRuleId;
  final int? steps;
  final int currentStep;
  final DateTime? dueDate;
  final DateTime? completedAt;

  Task({
    String? id,
    required this.title,
    this.category,
    this.status = TaskStatus.todo,
    required this.date,
    DateTime? createdAt,
    this.isCategoryPlaceholder = false,
    this.sourceRuleId,
    this.steps,
    this.currentStep = 0,
    this.dueDate,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    String? title,
    String? category,
    TaskStatus? status,
    DateTime? date,
    bool? isCategoryPlaceholder,
    String? sourceRuleId,
    bool clearSourceRuleId = false,
    int? steps,
    bool clearSteps = false,
    int? currentStep,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      status: status ?? this.status,
      date: date ?? this.date,
      createdAt: createdAt,
      isCategoryPlaceholder: isCategoryPlaceholder ?? this.isCategoryPlaceholder,
      sourceRuleId: clearSourceRuleId ? null : (sourceRuleId ?? this.sourceRuleId),
      steps: clearSteps ? null : (steps ?? this.steps),
      currentStep: currentStep ?? this.currentStep,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
  
  /// 检查任务是否逾期（派生状态，不修改 TaskStatus）
  /// 逾期 = 未完成 && 有截止日期 && 今天已过截止日期
  bool get isOverdue {
    if (status == TaskStatus.completed || dueDate == null) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return today.isAfter(dueDay);
  }
  
  /// 获取任务的活动日期（activeDate）用于列表挂载
  /// - 无截止日期：使用 date
  /// - 有截止日期且未完成：clamp(今天, date..due) 或今天如果已经逾期
  /// - 已完成：使用 completedAt 的日期
  DateTime get activeDate {
    if (status == TaskStatus.completed && completedAt != null) {
      final c = completedAt!;
      return DateTime(c.year, c.month, c.day);
    }
    
    if (dueDate == null) {
      return DateTime(date.year, date.month, date.day);
    }
    
    // 有截止日期且未完成
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(date.year, date.month, date.day);
    final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    
    // 如果今天在 startDay 之前，使用 startDay
    if (today.isBefore(startDay)) {
      return startDay;
    }
    
    // 如果今天在 dueDay 之后（逾期），使用今天
    if (today.isAfter(dueDay)) {
      return today;
    }
    
    // 否则使用今天（在范围内）
    return today;
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'status': status.index,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isCategoryPlaceholder': isCategoryPlaceholder,
      'sourceRuleId': sourceRuleId,
      'steps': steps,
      'currentStep': currentStep,
      'dueDate': dueDate?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  // Create from JSON (兼容旧数据，dueDate 和 completedAt 可能不存在)
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      category: json['category'],
      status: TaskStatus.values[json['status']],
      date: DateTime.parse(json['date']),
      createdAt: DateTime.parse(json['createdAt']),
      isCategoryPlaceholder: json['isCategoryPlaceholder'] ?? false,
      sourceRuleId: json['sourceRuleId'],
      steps: json['steps'],
      currentStep: json['currentStep'] ?? 0,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    );
  }
}
