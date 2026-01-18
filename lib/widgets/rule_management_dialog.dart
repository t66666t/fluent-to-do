import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rule_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';
import 'rule_editor_sheet.dart';

class RuleManagementDialog extends StatelessWidget {
  const RuleManagementDialog({super.key});

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
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: Consumer<RuleProvider>(
                      builder: (context, provider, child) {
                        if (provider.rules.isEmpty) {
                          return Center(
                            child: Text(
                              '暂无规则',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          );
                        }
                        return ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: provider.rules.length,
                          onReorder: (oldIndex, newIndex) {
                            provider.reorderRules(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final rule = provider.rules[index];
                            return _buildRuleItem(context, rule, provider, index);
                          },
                        );
                      },
                    ),
                  ),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              HapticHelper.light();
              Navigator.pop(context);
            },
            child: const Icon(Icons.arrow_back_ios, size: 20, color: AppTheme.primaryColor),
          ),
          Text('默认任务规则', style: AppTheme.titleMedium),
          const SizedBox(width: 20), // Placeholder for balance
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              HapticHelper.medium();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const RuleEditorSheet(),
              );
            },
            child: const Text('创建任务规则'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              HapticHelper.light();
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '确认',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(BuildContext context, dynamic rule, RuleProvider provider, int index) {
    final dayNames = ['一', '二', '三', '四', '五', '六', '日'];
    final activeDaysText = rule.activeDays
        .map((d) => dayNames[d - 1])
        .join(' ');

    return Dismissible(
      key: ValueKey(rule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        HapticHelper.medium();
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除这条规则吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        provider.deleteRule(rule.id);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
             HapticHelper.light();
             showModalBottomSheet(
               context: context,
               isScrollControlled: true,
               backgroundColor: Colors.transparent,
               builder: (context) => RuleEditorSheet(initialRule: rule),
             );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '周$activeDaysText',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: rule.isEnabled,
                  activeTrackColor: AppTheme.primaryColor,
                  onChanged: (val) {
                    HapticHelper.selection();
                    provider.toggleRule(rule.id);
                    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
                    if (val) {
                       taskProvider.forceApplyRule(rule);
                    } else {
                       taskProvider.retractTasksForRule(rule.id);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.drag_handle, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
