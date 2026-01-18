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
    );
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
    };
  }

  // Create from JSON
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
    );
  }
}
