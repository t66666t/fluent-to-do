import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fixed_work_provider.dart';
import '../models/fixed_work.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';
import '../widgets/fixed_work_editor.dart';
import '../widgets/fixed_work_timer.dart';

/// 固定工作管理页面
class FixedWorkScreen extends StatelessWidget {
  const FixedWorkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('固定工作', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<FixedWorkProvider>(
        builder: (context, provider, child) {
          // 如果有活跃会话，显示计时界面
          if (provider.hasActiveSession) {
            return FixedWorkTimer(session: provider.currentSession!);
          }
          
          // 否则显示模板列表
          return _buildTemplateList(context, provider);
        },
      ),
      floatingActionButton: Consumer<FixedWorkProvider>(
        builder: (context, provider, child) {
          // 只有在没有活跃会话时才显示添加按钮
          if (provider.hasActiveSession) {
            return const SizedBox.shrink();
          }
          
          return FloatingActionButton(
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              HapticHelper.medium();
              _showTemplateEditor(context, null);
            },
          );
        },
      ),
    );
  }

  Widget _buildTemplateList(BuildContext context, FixedWorkProvider provider) {
    if (provider.templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无固定工作模板',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角 + 创建新模板',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.templates.length,
      itemBuilder: (context, index) {
        final template = provider.templates[index];
        return _buildTemplateCard(context, provider, template);
      },
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    FixedWorkProvider provider,
    FixedWorkTemplate template,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticHelper.light();
            _showTemplateActions(context, provider, template);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.work_outline,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${template.stages.length} 个阶段 • ${template.totalDurationText}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        HapticHelper.light();
                        _showTemplateActions(context, provider, template);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 阶段列表
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: template.stages.map((stage) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            stage.type == StageType.point
                                ? Icons.circle
                                : Icons.timelapse,
                            size: 12,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stage.name} ${stage.durationText}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTemplateActions(
    BuildContext context,
    FixedWorkProvider provider,
    FixedWorkTemplate template,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.green),
              title: const Text('开始计时'),
              onTap: () {
                Navigator.pop(context);
                HapticHelper.medium();
                provider.startSession(template);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.primaryColor),
              title: const Text('编辑模板'),
              onTap: () {
                Navigator.pop(context);
                HapticHelper.light();
                _showTemplateEditor(context, template);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除模板'),
              onTap: () {
                Navigator.pop(context);
                HapticHelper.medium();
                _confirmDelete(context, provider, template);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showTemplateEditor(BuildContext context, FixedWorkTemplate? template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FixedWorkEditor(template: template),
        fullscreenDialog: true,
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    FixedWorkProvider provider,
    FixedWorkTemplate template,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定要删除「${template.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteTemplate(template.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('模板已删除')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
