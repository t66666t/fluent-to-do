import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/fixed_work.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';

/// 任务详情弹窗 - 显示任务详细信息并允许编辑截止日期
class TaskDetailSheet extends StatefulWidget {
  final Task task;
  
  const TaskDetailSheet({
    super.key,
    required this.task,
  });

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDueDate;
  
  @override
  void initState() {
    super.initState();
    _selectedDueDate = widget.task.dueDate;
    if (_selectedDueDate != null) {
      _focusedDay = _selectedDueDate!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: () {}, // 防止点击内容区关闭
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  _buildHeader(),
                  
                  // 内容区域
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 任务标题
                          _buildTaskTitle(),
                          const SizedBox(height: 24),
                          
                          // 任务信息
                          _buildTaskInfo(),
                          
                          // 固定工作阶段信息
                          if (widget.task.isFixedWork) ...[
                            const SizedBox(height: 24),
                            _buildFixedWorkStages(),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // 截止日期设置
                          _buildDueDateSection(),
                        ],
                      ),
                    ),
                  ),
                  
                  // 底部按钮
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '任务详情',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 状态图标
            Icon(
              widget.task.status == TaskStatus.completed
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: widget.task.status == TaskStatus.completed
                  ? Colors.green
                  : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 12),
            
            // 任务标题
            Expanded(
              child: Text(
                widget.task.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        
        // 逾期标签
        if (widget.task.isOverdue) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.overdueColorLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber, size: 16, color: AppTheme.overdueColor),
                SizedBox(width: 4),
                Text(
                  '逾期',
                  style: TextStyle(
                    color: AppTheme.overdueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTaskInfo() {
    final dateFormat = DateFormat('yyyy年MM月dd日');
    
    return Column(
      children: [
        _buildInfoRow(
          icon: Icons.calendar_today,
          label: '创建日期',
          value: dateFormat.format(widget.task.date),
        ),
        
        if (widget.task.category != null) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.label_outline,
            label: '分类',
            value: widget.task.category!,
          ),
        ],
        
        if (widget.task.steps != null) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.format_list_numbered,
            label: '进度',
            value: '${widget.task.currentStep} / ${widget.task.steps}',
          ),
        ],
        
        if (widget.task.completedAt != null) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.check_circle_outline,
            label: '完成时间',
            value: dateFormat.format(widget.task.completedAt!),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildDueDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '截止日期',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            if (_selectedDueDate != null)
              TextButton(
                onPressed: () {
                  HapticHelper.light();
                  setState(() {
                    _selectedDueDate = null;
                  });
                },
                child: const Text('清除'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        // 快捷日期选择按钮
        _buildQuickDateButtons(),
        const SizedBox(height: 16),
        
        // 日历选择器
        _buildCalendar(),
        const SizedBox(height: 12),
        
        // 当前选择的截止日期
        if (_selectedDueDate != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.event, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '截止日期：${DateFormat('yyyy年MM月dd日').format(_selectedDueDate!)}',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuickDateButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildQuickButton('今天', 0),
        _buildQuickButton('明天', 1),
        _buildQuickButton('3 天后', 3),
        _buildQuickButton('7 天后', 7),
      ],
    );
  }

  Widget _buildQuickButton(String label, int daysFromNow) {
    final targetDate = DateTime.now().add(Duration(days: daysFromNow));
    final isSelected = _selectedDueDate != null &&
        _isSameDay(_selectedDueDate!, targetDate);
    
    return InkWell(
      onTap: () {
        HapticHelper.light();
        setState(() {
          _selectedDueDate = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
          );
          _focusedDay = _selectedDueDate!;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return TableCalendar(
      firstDay: today,
      lastDay: today.add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) {
        return _selectedDueDate != null && _isSameDay(day, _selectedDueDate!);
      },
      onDaySelected: (selectedDay, focusedDay) {
        HapticHelper.light();
        setState(() {
          _selectedDueDate = DateTime(
            selectedDay.year,
            selectedDay.month,
            selectedDay.day,
          );
          _focusedDay = focusedDay;
        });
      },
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        selectedDecoration: BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        // 逾期日期使用弱琥珀色
        defaultDecoration: BoxDecoration(
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          // 如果是过去的日期且在创建日期之后，显示为逾期色
          if (widget.task.dueDate != null && day.isBefore(today)) {
            final dueDay = DateTime(
              widget.task.dueDate!.year,
              widget.task.dueDate!.month,
              widget.task.dueDate!.day,
            );
            if (day.isAfter(dueDay) || _isSameDay(day, dueDay)) {
              return Center(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.overdueColorLight,
                    shape: BoxShape.circle,
                  ),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(color: AppTheme.overdueColor),
                  ),
                ),
              );
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                HapticHelper.light();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                HapticHelper.medium();
                context.read<TaskProvider>().updateTaskDueDate(
                  widget.task.id,
                  _selectedDueDate,
                );
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '保存',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildFixedWorkStages() {
    final stages = widget.task.fixedWorkStages;
    if (stages == null || stages.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '工作阶段',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.fixedWorkColorLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ...List.generate(stages.length, (index) {
                final stage = stages[index];
                return Column(
                  children: [
                    if (index > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.fixedWorkColor),
                    ListTile(
                      dense: true,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppTheme.fixedWorkColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        stage.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            stage.type == StageType.point
                                ? Icons.circle
                                : Icons.timelapse,
                            size: 14,
                            color: AppTheme.fixedWorkColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stage.durationText,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.fixedWorkColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.timer, size: 16, color: AppTheme.fixedWorkColor),
                    const SizedBox(width: 4),
                    Text(
                      '总计：${widget.task.fixedWorkDurationText}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.fixedWorkColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
