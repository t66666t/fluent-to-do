class TaskRule {
  final String id;
  final String name;
  final String content;
  final List<int> activeDays; // 1 = Monday, 7 = Sunday
  final bool isEnabled;

  TaskRule({
    required this.id,
    required this.name,
    required this.content,
    required this.activeDays,
    this.isEnabled = true,
  });

  TaskRule copyWith({
    String? id,
    String? name,
    String? content,
    List<int>? activeDays,
    bool? isEnabled,
  }) {
    return TaskRule(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      activeDays: activeDays ?? this.activeDays,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'activeDays': activeDays,
      'isEnabled': isEnabled,
    };
  }

  factory TaskRule.fromJson(Map<String, dynamic> json) {
    return TaskRule(
      id: json['id'],
      name: json['name'],
      content: json['content'],
      activeDays: List<int>.from(json['activeDays']),
      isEnabled: json['isEnabled'] ?? true,
    );
  }
}
