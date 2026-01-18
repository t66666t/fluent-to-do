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

    return Stack(
      children: [
        Container(
          color: AppTheme.cardColor,
          child: TableCalendar<Task>(
            firstDay: DateTime.utc(2020, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: taskProvider.selectedDate,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarFormat: _calendarFormat,
            eventLoader: (day) => taskProvider.getCalendarEvents(day),
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
              formatButtonVisible: false, // Hide default button to fix title position
              titleCentered: true,
              formatButtonShowsNext: false,
              rightChevronMargin: EdgeInsets.only(right: 96), // 12 (right) + 80 (width) + 4 (gap)
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                // Check if we should hide markers for future dates
                if (taskProvider.hideFutureTasksInCalendar) {
                  final now = DateTime.now();
                  final isFuture = date.year > now.year ||
                      (date.year == now.year && date.month > now.month) ||
                      (date.year == now.year &&
                          date.month == now.month &&
                          date.day > now.day);
                  
                  if (isFuture) {
                    return const _StatusDot(color: null);
                  }
                }

                Color? color;
                if (events.isNotEmpty) {
                  final tasks = events.where((t) => !t.isCategoryPlaceholder).toList();

                  if (tasks.isNotEmpty) {
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
                }

                return _StatusDot(color: color);
              },
            ),
          ),
        ),
        // Custom Format Button positioned absolutely
        Positioned(
          right: 12,
          top: 16, // Adjusted to align center with standard icon button (48px height)
          child: _buildFormatButton(),
        ),
      ],
    );
  }

  Widget _buildFormatButton() {
    String text;
    switch (_calendarFormat) {
      case CalendarFormat.month:
        text = 'Month';
        break;
      case CalendarFormat.twoWeeks:
        text = '2 Weeks';
        break;
      case CalendarFormat.week:
        text = 'Week';
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticHelper.light();
          setState(() {
            if (_calendarFormat == CalendarFormat.week) {
              _calendarFormat = CalendarFormat.twoWeeks;
            } else if (_calendarFormat == CalendarFormat.twoWeeks) {
              _calendarFormat = CalendarFormat.month;
            } else {
              _calendarFormat = CalendarFormat.week;
            }
          });
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: 80, // Fixed width for consistency
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
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
