import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';
import 'rule_management_dialog.dart';

class SettingsDialog extends StatelessWidget {
  final VoidCallback? onClose;

  const SettingsDialog({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
      },
      behavior: HitTestBehavior.opaque,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: () {}, // Prevent tap from closing dialog when clicking content
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Center(
                      child: Text(
                        '设置',
                        style: AppTheme.titleMedium,
                      ),
                    ),
                  ),
                  
                  // Settings List
                  Consumer<TaskProvider>(
                    builder: (context, provider, child) {
                      return Column(
                          children: [
                            _buildSwitchItem(
                              title: '自动收起已完成的类别',
                              value: provider.autoCollapseCategory,
                              onChanged: (val) {
                                HapticHelper.selection();
                                provider.setAutoCollapseCategory(val);
                              },
                            ),
                            _buildSwitchItem(
                              title: '隐藏未来日程状态',
                              value: provider.hideFutureTasksInCalendar,
                              onChanged: (val) {
                                HapticHelper.selection();
                                provider.setHideFutureTasksInCalendar(val);
                              },
                            ),
                            const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.black12),
                            _buildActionItem(
                              context,
                              title: '默认任务规则',
                              onTap: () {
                                HapticHelper.light();
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    opaque: false,
                                    pageBuilder: (ctx, anim, secAnim) => const RuleManagementDialog(),
                                    transitionsBuilder: (ctx, anim, secAnim, child) {
                                      return FadeTransition(
                                        opacity: anim,
                                        child: ScaleTransition(
                                          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                                            CurvedAnimation(parent: anim, curve: Curves.easeOutQuart),
                                          ),
                                          child: child,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.black12),
                            _buildSwitchItem(
                              title: '开启震动反馈',
                              value: provider.vibrationEnabled,
                              onChanged: (val) {
                                provider.setVibrationEnabled(val);
                                if (val) {
                                  HapticHelper.medium();
                                }
                              },
                            ),
                            // Add more settings here in future
                          ],
                        );
                    },
                  ),
                  
                  // Footer / Close Button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        HapticHelper.light();
                        Navigator.of(context).pop();
                      },
                      child: const Text('完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTheme.bodyMedium,
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTheme.bodyMedium,
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
