import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_rule.dart';
import '../providers/rule_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';

class RuleEditorSheet extends StatefulWidget {
  final TaskRule? initialRule;

  const RuleEditorSheet({super.key, this.initialRule});

  @override
  State<RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends State<RuleEditorSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  late List<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    if (widget.initialRule != null) {
      _nameController.text = widget.initialRule!.name;
      _contentController.text = widget.initialRule!.content;
      _selectedDays = List.from(widget.initialRule!.activeDays);
    } else {
      _selectedDays = [1, 2, 3, 4, 5, 6, 7];
    }
  }

  void _toggleDay(int day) {
    HapticHelper.selection();
    setState(() {
      if (_selectedDays.contains(day)) {
        if (_selectedDays.length > 1) {
          _selectedDays.remove(day);
        }
      } else {
        _selectedDays.add(day);
        _selectedDays.sort();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRule != null;
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
              Text(isEditing ? '编辑任务规则' : '创建任务规则', style: AppTheme.titleMedium),
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
          // Name Field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '规则名称',
              hintText: '例如：工作日默认任务',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppTheme.backgroundColor,
            ),
          ),
          const SizedBox(height: 16),
          // Day Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 1; i <= 7; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _buildDayToggle(i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '输入任务规则...\n例如：\n。工作\n早会\n查邮件',
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
              if (_contentController.text.isNotEmpty) {
                HapticHelper.heavy();
                final provider = Provider.of<RuleProvider>(context, listen: false);
                final name = _nameController.text.isNotEmpty 
                    ? _nameController.text 
                    : (isEditing ? widget.initialRule!.name : null);

                if (isEditing) {
                  provider.updateRule(
                    widget.initialRule!.id,
                    _contentController.text,
                    _selectedDays,
                    name: name,
                  );
                } else {
                  provider.addRule(
                    _contentController.text,
                    _selectedDays,
                    name: name,
                  );
                }
                Navigator.pop(context);
              } else {
                HapticHelper.selection();
              }
            },
            child: const Text('保存'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDayToggle(int day) {
    final isSelected = _selectedDays.contains(day);
    final dayNames = ['一', '二', '三', '四', '五', '六', '日'];
    return GestureDetector(
      onTap: () => _toggleDay(day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
          shape: BoxShape.circle,
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text(
          dayNames[day - 1],
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
