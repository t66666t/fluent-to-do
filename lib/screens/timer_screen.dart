import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            '计时模式',
            style: AppTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '即将推出',
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
