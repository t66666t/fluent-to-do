import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    return Container(
      color: AppTheme.cardColor,
      child: TableCalendar<Task>(
        firstDay: DateTime.utc(2020, 10, 16),
        lastDay: DateTime.utc(2030, 3, 14),
        focusedDay: taskProvider.selectedDate,
        calendarFormat: _calendarFormat,
        eventLoader: (day) => taskProvider.getTasksForDay(day),
        selectedDayPredicate: (day) {
          return isSameDay(taskProvider.selectedDate, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(taskProvider.selectedDate, selectedDay)) {
             HapticHelper.selection();
             taskProvider.selectDate(selectedDay);
          }
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
             HapticHelper.light();
             setState(() {
               _calendarFormat = format;
             });
          }
        },
        onPageChanged: (focusedDay) {
          HapticHelper.light();
        },
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Color(0xFFE5F1FF),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
          markersAlignment: Alignment.bottomRight,
          markersMaxCount: 1,
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            Color? color;
            if (events.isNotEmpty) {
              final tasks = events;
              final hasInProgress = tasks.any((t) => t.status == TaskStatus.inProgress);
              final hasCompleted = tasks.any((t) => t.status == TaskStatus.completed);
              final hasTodo = tasks.any((t) => t.status == TaskStatus.todo);

              final allCompleted = tasks.every((t) => t.status == TaskStatus.completed);
              final allTodo = tasks.every((t) => t.status == TaskStatus.todo);

              if (allCompleted) {
                color = AppTheme.successColor;
              } else if (allTodo) {
                color = const Color(0xFF8E8E93); // Grey
              } else {
                // Mixed or InProgress -> Blue
                color = AppTheme.primaryColor;
              }
            }

            return _StatusDot(color: color);
          },
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color? color;

  const _StatusDot({this.color});

  @override
  Widget build(BuildContext context) {
    final isVisible = color != null;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      width: isVisible ? 6 : 0,
      height: isVisible ? 6 : 0,
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.transparent,
        shape: BoxShape.circle,
      ),
    );
  }
}
