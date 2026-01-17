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

  Task({
    String? id,
    required this.title,
    this.category,
    this.status = TaskStatus.todo,
    required this.date,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    String? title,
    String? category,
    TaskStatus? status,
    DateTime? date,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      status: status ?? this.status,
      date: date ?? this.date,
      createdAt: createdAt,
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
    );
  }
}
