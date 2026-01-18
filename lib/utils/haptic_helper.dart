import 'package:flutter/services.dart';

class HapticHelper {
  // Prevent instantiation
  HapticHelper._();

  /// 全局震动开关
  static bool enabled = true;

  /// 轻微的震动，用于普通点击或按钮交互
  static Future<void> light() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// 中等震动，用于重要操作或状态改变
  static Future<void> medium() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
  }
  
  /// 较重的震动，用于完成任务或长按
  static Future<void> heavy() async {
    if (!enabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// 选择震动，用于开关切换、拖拽排序刻度感
  static Future<void> selection() async {
    if (!enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// 成功操作震动
  static Future<void> success() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
  }
}
