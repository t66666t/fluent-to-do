import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/rule_management_dialog.dart';
import '../utils/haptic_helper.dart';
import '../utils/demo_data_loader.dart';
import '../providers/task_provider.dart';
import '../providers/rule_provider.dart';
import '../providers/fixed_work_provider.dart';
import 'fixed_work_screen.dart';

/// More标签页 - 提供额外功能和设置的入口
/// 
/// 包含功能：
/// - 默认任务规则
/// - 固定工作管理
/// - 加载示例数据
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          '更多',
          style: AppTheme.titleLarge.copyWith(fontSize: 24),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 任务管理卡片
            _buildSectionCard(
              context,
              title: '任务管理',
              items: [
                _MoreCardItem(
                  icon: Icons.rule,
                  iconColor: AppTheme.primaryColor,
                  title: '默认任务规则',
                  subtitle: '设置每周自动生成的任务',
                  onTap: () {
                    HapticHelper.light();
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: false,
                        pageBuilder: (ctx, anim, secAnim) => const RuleManagementDialog(),
                        transitionsBuilder: (ctx, anim, secAnim, child) {
                          return FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                                CurvedAnimation(parent: anim, curve: Curves.easeOutQuart),
                              ),
                              child: child,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                _MoreCardItem(
                  icon: Icons.work_outline,
                  iconColor: Colors.blue,
                  title: '固定工作',
                  subtitle: '管理固定工作模板',
                  onTap: () {
                    HapticHelper.light();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const FixedWorkScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 数据管理卡片
            _buildSectionCard(
              context,
              title: '数据管理',
              items: [
                _MoreCardItem(
                  icon: Icons.download,
                  iconColor: Colors.green,
                  title: '加载示例数据',
                  subtitle: '体验完整功能',
                  onTap: () {
                    HapticHelper.light();
                    _showDemoDataOptions(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建功能卡片分组
  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required List<_MoreCardItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
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
              for (int i = 0; i < items.length; i++) ...[
                _buildMoreItem(items[i]),
                if (i < items.length - 1)
                  const Divider(height: 1, indent: 60, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 构建单个功能项
  Widget _buildMoreItem(_MoreCardItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.icon,
                color: item.iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            
            // 文本
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // 箭头
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

  /// 显示示例数据加载选项
  void _showDemoDataOptions(BuildContext context) {
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '加载示例数据',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.blue),
              title: const Text('追加到现有数据'),
              subtitle: const Text('保留当前任务，添加示例数据'),
              onTap: () {
                Navigator.pop(context);
                _loadDemoData(context, clearExisting: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('清空并加载'),
              subtitle: const Text('删除所有现有数据，加载全新示例'),
              onTap: () {
                Navigator.pop(context);
                _confirmClearAndLoad(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 确认清空并加载
  void _confirmClearAndLoad(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('这将删除所有现有任务、规则和模板。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadDemoData(context, clearExisting: true);
            },
            child: const Text(
              '确定',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// 加载示例数据
  Future<void> _loadDemoData(BuildContext context, {required bool clearExisting}) async {
    HapticHelper.heavy();

    // 显示加载提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在加载示例数据...'),
        duration: Duration(seconds: 1),
      ),
    );

    final taskProvider = context.read<TaskProvider>();
    final ruleProvider = context.read<RuleProvider>();
    final fixedWorkProvider = context.read<FixedWorkProvider>();

    try {
      await DemoDataLoader.loadDemoData(
        taskProvider,
        ruleProvider,
        fixedWorkProvider,
        clearExisting: clearExisting,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('示例数据加载成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 功能项数据类
class _MoreCardItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _MoreCardItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
