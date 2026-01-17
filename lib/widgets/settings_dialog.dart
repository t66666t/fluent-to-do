import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';

class SettingsDialog extends StatelessWidget {
  final VoidCallback? onClose;

  const SettingsDialog({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    // Apple-style dialog
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '设置',
                    style: AppTheme.titleMedium.copyWith(fontSize: 18),
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
                          // Add more settings here in future
                        ],
                      );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Footer / Close Button
                const Divider(height: 1, color: Colors.black12),
                InkWell(
                  onTap: () {
                    HapticHelper.light();
                    onClose?.call();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: Text(
                      '完成',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
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
            activeColor: AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
