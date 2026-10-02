import 'package:uuid/uuid.dart';

/// 固定工作阶段类型
enum StageType {
  point,  // 点式：单个时长
  range,  // 区间式：最小-最大时长范围
}

/// 固定工作阶段
class Stage {
  final String id;
  final String name;
  final StageType type;
  final int duration;        // 点式：时长（秒），区间式：最小时长（秒）
  final int? maxDuration;    // 仅区间式使用：最大时长（秒）
  
  Stage({
    String? id,
    required this.name,
    required this.type,
    required this.duration,
    this.maxDuration,
  }) : id = id ?? const Uuid().v4();
  
  Stage copyWith({
    String? name,
    StageType? type,
    int? duration,
    int? maxDuration,
    bool clearMaxDuration = false,
  }) {
    return Stage(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      maxDuration: clearMaxDuration ? null : (maxDuration ?? this.maxDuration),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'duration': duration,
      'maxDuration': maxDuration,
    };
  }
  
  factory Stage.fromJson(Map<String, dynamic> json) {
    return Stage(
      id: json['id'],
      name: json['name'],
      type: StageType.values[json['type']],
      duration: json['duration'],
      maxDuration: json['maxDuration'],
    );
  }
  
  /// 获取阶段的显示时长文本
  String get durationText {
    if (type == StageType.point) {
      return _formatDuration(duration);
    } else {
      return '${_formatDuration(duration)}-${_formatDuration(maxDuration ?? duration)}';
    }
  }
  
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${secs}s';
    }
  }
}

/// 固定工作模板
class FixedWorkTemplate {
  final String id;
  final String name;
  final List<Stage> stages;
  final DateTime createdAt;
  
  FixedWorkTemplate({
    String? id,
    required this.name,
    required this.stages,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
  
  FixedWorkTemplate copyWith({
    String? name,
    List<Stage>? stages,
  }) {
    return FixedWorkTemplate(
      id: id,
      name: name ?? this.name,
      stages: stages ?? this.stages,
      createdAt: createdAt,
    );
  }
  
  /// 计算模板的总时长（使用点式时长或区间最小值）
  int get totalDuration {
    return stages.fold(0, (sum, stage) => sum + stage.duration);
  }
  
  /// 获取总时长的文本表示
  String get totalDurationText {
    final seconds = totalDuration;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '$hours小时${minutes}分钟';
    } else {
      return '$minutes分钟';
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stages': stages.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  factory FixedWorkTemplate.fromJson(Map<String, dynamic> json) {
    return FixedWorkTemplate(
      id: json['id'],
      name: json['name'],
      stages: (json['stages'] as List).map((s) => Stage.fromJson(s)).toList(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

/// 固定工作计时会话
class FixedWorkSession {
  final String id;
  final String templateId;
  final String templateName;
  final List<Stage> stages;          // 阶段快照
  final DateTime startTime;
  final DateTime? endTime;
  final int currentStageIndex;
  final int currentStageElapsed;     // 当前阶段已用时间（秒）
  final bool isPaused;
  final DateTime? lastPauseTime;
  final int totalPausedDuration;     // 总暂停时长（秒）
  
  FixedWorkSession({
    String? id,
    required this.templateId,
    required this.templateName,
    required this.stages,
    DateTime? startTime,
    this.endTime,
    this.currentStageIndex = 0,
    this.currentStageElapsed = 0,
    this.isPaused = false,
    this.lastPauseTime,
    this.totalPausedDuration = 0,
  })  : id = id ?? const Uuid().v4(),
        startTime = startTime ?? DateTime.now();
  
  FixedWorkSession copyWith({
    DateTime? endTime,
    bool clearEndTime = false,
    int? currentStageIndex,
    int? currentStageElapsed,
    bool? isPaused,
    DateTime? lastPauseTime,
    bool clearLastPauseTime = false,
    int? totalPausedDuration,
  }) {
    return FixedWorkSession(
      id: id,
      templateId: templateId,
      templateName: templateName,
      stages: stages,
      startTime: startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      currentStageIndex: currentStageIndex ?? this.currentStageIndex,
      currentStageElapsed: currentStageElapsed ?? this.currentStageElapsed,
      isPaused: isPaused ?? this.isPaused,
      lastPauseTime: clearLastPauseTime ? null : (lastPauseTime ?? this.lastPauseTime),
      totalPausedDuration: totalPausedDuration ?? this.totalPausedDuration,
    );
  }
  
  /// 检查会话是否已完成
  bool get isCompleted => endTime != null;
  
  /// 获取当前阶段
  Stage? get currentStage {
    if (currentStageIndex < 0 || currentStageIndex >= stages.length) {
      return null;
    }
    return stages[currentStageIndex];
  }
  
  /// 计算总用时（包含暂停时间）
  int get totalElapsedSeconds {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inSeconds;
  }
  
  /// 计算实际工作时长（不包含暂停时间）
  int get actualWorkSeconds {
    return totalElapsedSeconds - totalPausedDuration;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateId': templateId,
      'templateName': templateName,
      'stages': stages.map((s) => s.toJson()).toList(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'currentStageIndex': currentStageIndex,
      'currentStageElapsed': currentStageElapsed,
      'isPaused': isPaused,
      'lastPauseTime': lastPauseTime?.toIso8601String(),
      'totalPausedDuration': totalPausedDuration,
    };
  }
  
  factory FixedWorkSession.fromJson(Map<String, dynamic> json) {
    return FixedWorkSession(
      id: json['id'],
      templateId: json['templateId'],
      templateName: json['templateName'],
      stages: (json['stages'] as List).map((s) => Stage.fromJson(s)).toList(),
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      currentStageIndex: json['currentStageIndex'] ?? 0,
      currentStageElapsed: json['currentStageElapsed'] ?? 0,
      isPaused: json['isPaused'] ?? false,
      lastPauseTime: json['lastPauseTime'] != null 
          ? DateTime.parse(json['lastPauseTime']) 
          : null,
      totalPausedDuration: json['totalPausedDuration'] ?? 0,
    );
  }
}
