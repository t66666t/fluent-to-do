import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fixed_work_provider.dart';
import '../models/fixed_work.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';

/// 固定工作计时器界面
class FixedWorkTimer extends StatelessWidget {
  final FixedWorkSession session;
  
  const FixedWorkTimer({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final currentStage = session.currentStage;
    
    return Container(
      color: AppTheme.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // 顶部信息栏
            _buildHeader(context),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 当前阶段卡片
                    if (currentStage != null)
                      _buildCurrentStageCard(currentStage),
                    
                    const SizedBox(height: 24),
                    
                    // 所有阶段列表
                    _buildStagesList(),
                  ],
                ),
              ),
            ),
            
            // 底部控制按钮
            _buildControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              HapticHelper.light();
              _showCancelConfirmation(context);
            },
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  session.templateName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTotalTime(session.actualWorkSeconds),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // 平衡左侧按钮
        ],
      ),
    );
  }

  Widget _buildCurrentStageCard(Stage currentStage) {
    final progress = _calculateStageProgress();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '阶段 ${session.currentStageIndex + 1}/${session.stages.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                currentStage.type == StageType.point
                    ? Icons.circle
                    : Icons.timelapse,
                color: Colors.white.withValues(alpha: 0.9),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 阶段名称
          Text(
            currentStage.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // 计时器显示
          Text(
            _formatTime(session.currentStageElapsed),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            '目标：${currentStage.durationText}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          
          // 进度条
          if (currentStage.type == StageType.point) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStagesList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ...List.generate(session.stages.length, (index) {
            final stage = session.stages[index];
            final isCurrent = index == session.currentStageIndex;
            final isCompleted = index < session.currentStageIndex;
            
            return Column(
              children: [
                if (index > 0)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.withValues(alpha: 0.1)
                          : isCurrent
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 18,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent
                                    ? AppTheme.primaryColor
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  title: Text(
                    stage.name,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted
                          ? Colors.grey.shade500
                          : Colors.black,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
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
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stage.durationText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final provider = context.watch<FixedWorkProvider>();
    final isLastStage = session.currentStageIndex >= session.stages.length - 1;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 暂停/恢复按钮
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                HapticHelper.medium();
                if (session.isPaused) {
                  provider.resumeSession();
                } else {
                  provider.pauseSession();
                }
              },
              icon: Icon(
                session.isPaused ? Icons.play_arrow : Icons.pause,
              ),
              label: Text(session.isPaused ? '恢复' : '暂停'),
              style: ElevatedButton.styleFrom(
                backgroundColor: session.isPaused
                    ? Colors.green
                    : Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // 下一阶段/完成按钮
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                HapticHelper.heavy();
                if (isLastStage) {
                  provider.finishSession();
                  _showCompletionDialog(context);
                } else {
                  provider.nextStage();
                }
              },
              icon: Icon(isLastStage ? Icons.check : Icons.arrow_forward),
              label: Text(isLastStage ? '完成' : '下一阶段'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStage ? Colors.green : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateStageProgress() {
    final currentStage = session.currentStage;
    if (currentStage == null || currentStage.type != StageType.point) {
      return 0.0;
    }
    
    return (session.currentStageElapsed / currentStage.duration).clamp(0.0, 1.0);
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  String _formatTotalTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '总计 ${hours}h ${minutes}m';
    } else {
      return '总计 ${minutes}m';
    }
  }

  void _showCancelConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消计时'),
        content: const Text('确定要取消当前计时吗？进度将不会被保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续计时'),
          ),
          TextButton(
            onPressed: () {
              context.read<FixedWorkProvider>().cancelSession();
              Navigator.pop(context);
            },
            child: const Text('确定取消', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('完成！'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('恭喜完成「${session.templateName}」！'),
            const SizedBox(height: 8),
            Text(
              '总用时：${_formatTotalTime(session.actualWorkSeconds)}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
