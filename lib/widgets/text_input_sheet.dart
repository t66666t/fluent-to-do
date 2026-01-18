import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/rule_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';

class TextInputSheet extends StatefulWidget {
  const TextInputSheet({super.key});

  @override
  State<TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<TextInputSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _generateInitialText();
      _isInit = false;
    }
  }

  void _generateInitialText() {
    final provider = Provider.of<TaskProvider>(context, listen: false);
    final items = provider.homeDisplayItems;
    final buffer = StringBuffer();

    if (items.isEmpty) {
      // If no tasks, load default rules
      final ruleProvider = Provider.of<RuleProvider>(context, listen: false);
      final ruleText = ruleProvider.getRulesTextForDate(provider.selectedDate);
      if (ruleText.isNotEmpty) {
        buffer.writeln(ruleText);
      }
    } else {
      String? lastCategoryContext;

      for (final item in items) {
        if (item is String) {
          // Category
          buffer.writeln('。$item');
          lastCategoryContext = item;

          final tasks = provider.getTasksForCategory(item);
          for (final task in tasks) {
            buffer.writeln(task.title);
            if (task.steps != null) {
              buffer.writeln(' ${task.steps}');
            }
          }
        } else if (item is Task) {
          // Uncategorized Task
          if (lastCategoryContext != null || buffer.isEmpty) {
            buffer.writeln('。');
            lastCategoryContext = null;
          }
          buffer.writeln(item.title);
          if (item.steps != null) {
            buffer.writeln(' ${item.steps}');
          }
        }
      }
    }

    _controller.text = buffer.toString();
  }

  void _showHelp() {
    showDialog(
      context: context,
      barrierColor: Colors.black12, // Light backdrop
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Text('识别逻辑说明', style: AppTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 24),
                _buildHelpItem('1. 类别', '以中文句号 "。" 或英文句号 "." 开头\n例如：。工作'),
                const SizedBox(height: 16),
                _buildHelpItem('2. 任务', '直接输入任务名称\n例如：完成报告'),
                const SizedBox(height: 16),
                _buildHelpItem('3. 步骤', '任务下一行开头空格加数字\n例如： 5 (表示5个步骤)'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                       HapticHelper.light();
                       Navigator.pop(context);
                    },
                    child: const Text('我知道了'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        Text(content, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('当日任务', style: AppTheme.titleMedium),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticHelper.light();
                      _showHelp();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Icon(Icons.question_mark_rounded, size: 14, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  HapticHelper.medium();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '输入任务...\n以 "。" 或 "." 开头的行将作为类别',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppTheme.backgroundColor,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              HapticHelper.heavy();
              Provider.of<TaskProvider>(context, listen: false)
                  .syncTasksFromText(_controller.text);
              Navigator.pop(context);
            },
            child: const Text('保存更改'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
