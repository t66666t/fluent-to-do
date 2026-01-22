import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class StepProgressBadge extends StatelessWidget {
  final TaskStatus status;
  final int currentStep;
  final int totalSteps;
  final double size;
  final BorderRadius borderRadius;

  const StepProgressBadge({
    super.key,
    required this.status,
    required this.currentStep,
    required this.totalSteps,
    this.size = 32,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  Color _statusColor() {
    switch (status) {
      case TaskStatus.todo:
        return AppTheme.textSecondary;
      case TaskStatus.inProgress:
        return AppTheme.primaryColor;
      case TaskStatus.completed:
        return AppTheme.successColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final progress = totalSteps <= 0
        ? 0.0
        : (currentStep / totalSteps).clamp(0.0, 1.0).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: borderRadius,
              border: Border.all(
                color: statusColor.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    heightFactor: value,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                          alpha: status == TaskStatus.todo ? 0.10 : 0.18,
                        ),
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: AnimatedDefaultTextStyle(
                      key: ValueKey<int>(currentStep),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      style: AppTheme.bodySmall.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: statusColor.withValues(alpha: 0.95),
                      ),
                      child: Text('$currentStep'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
