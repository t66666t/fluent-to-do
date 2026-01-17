import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';

class TextInputSheet extends StatefulWidget {
  const TextInputSheet({super.key});

  @override
  State<TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<TextInputSheet> {
  final TextEditingController _controller = TextEditingController();

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
              Text('导入任务', style: AppTheme.titleMedium),
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
              if (_controller.text.isNotEmpty) {
                HapticHelper.heavy();
                Provider.of<TaskProvider>(context, listen: false)
                    .importTasksFromText(_controller.text);
                Navigator.pop(context);
              } else {
                HapticHelper.selection();
              }
            },
            child: const Text('开始识别'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
