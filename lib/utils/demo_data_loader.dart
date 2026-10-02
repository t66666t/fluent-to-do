import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/task_rule.dart';
import '../models/fixed_work.dart';
import '../providers/task_provider.dart';
import '../providers/rule_provider.dart';
import '../providers/fixed_work_provider.dart';

/// 示例数据加载器
class DemoDataLoader {
  /// 检查是否已加载过示例数据
  static Future<bool> hasDemoDataLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('demo_data_loaded') ?? false;
  }

  /// 标记示例数据已加载
  static Future<void> markDemoDataLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('demo_data_loaded', true);
  }

  /// 加载示例数据（自动或手动）
  static Future<void> loadDemoData(
    TaskProvider taskProvider,
    RuleProvider ruleProvider,
    FixedWorkProvider fixedWorkProvider, {
    bool clearExisting = false,
  }) async {
    if (clearExisting) {
      // 清空现有数据
      await _clearAllData();
    }

    // 加载固定工作模板
    _loadFixedWorkTemplates(fixedWorkProvider);

    // 加载任务规则
    _loadTaskRules(ruleProvider);

    // 加载示例任务
    await _loadTasks(taskProvider, fixedWorkProvider);

    // 标记已加载
    await markDemoDataLoaded();
  }

  /// 清空所有数据
  static Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tasks');
    await prefs.remove('dailyDisplayOrders');
    await prefs.remove('clearedDates');
    await prefs.remove('categoryExpansionStates');
    await prefs.remove('task_rules');
    await prefs.remove('fixed_work_templates');
    await prefs.remove('fixed_work_session');
  }

  /// 加载固定工作模板
  static void _loadFixedWorkTemplates(FixedWorkProvider provider) {
    // 模板1: 深度工作
    final deepWorkTemplate = FixedWorkTemplate(
      name: '深度工作',
      stages: [
        Stage(
          name: '准备',
          type: StageType.point,
          duration: 300, // 5分钟
        ),
        Stage(
          name: '专注工作',
          type: StageType.range,
          duration: 2700, // 45分钟
          maxDuration: 5400, // 90分钟
        ),
        Stage(
          name: '休息',
          type: StageType.point,
          duration: 600, // 10分钟
        ),
      ],
    );

    // 模板2: 番茄工作法
    final pomodoroTemplate = FixedWorkTemplate(
      name: '番茄工作法',
      stages: [
        Stage(
          name: '工作',
          type: StageType.point,
          duration: 1500, // 25分钟
        ),
        Stage(
          name: '短休息',
          type: StageType.point,
          duration: 300, // 5分钟
        ),
      ],
    );

    // 模板3: 晨间锻炼
    final morningWorkoutTemplate = FixedWorkTemplate(
      name: '晨间锻炼',
      stages: [
        Stage(
          name: '热身',
          type: StageType.point,
          duration: 600, // 10分钟
        ),
        Stage(
          name: '有氧运动',
          type: StageType.range,
          duration: 1200, // 20分钟
          maxDuration: 1800, // 30分钟
        ),
        Stage(
          name: '力量训练',
          type: StageType.point,
          duration: 900, // 15分钟
        ),
        Stage(
          name: '拉伸放松',
          type: StageType.point,
          duration: 600, // 10分钟
        ),
      ],
    );

    provider.addTemplate(deepWorkTemplate);
    provider.addTemplate(pomodoroTemplate);
    provider.addTemplate(morningWorkoutTemplate);
  }

  /// 加载任务规则
  static void _loadTaskRules(RuleProvider provider) {
    // 周一到周五的工作日规则
    // 使用 addRule 方法，它会自动生成 ID 并创建规则
    // 注意：默认启用状态由 TaskRule 的默认值控制（isEnabled = true）
    // 如果需要禁用，需要在添加后手动更新
    provider.addRule(
      '''。工作
检查邮件
团队站会
项目进展

。生活
阅读30分钟
 3''',
      [1, 2, 3, 4, 5], // 周一到周五
      name: '工作日常规',
    );
  }

  /// 加载示例任务
  static Future<void> _loadTasks(
    TaskProvider taskProvider,
    FixedWorkProvider fixedWorkProvider,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final threeDaysAgo = today.subtract(const Duration(days: 3));

    final tasks = <Task>[
      // 今天的任务 - 普通任务
      Task(
        title: '准备周会演示文稿',
        category: '工作',
        status: TaskStatus.inProgress,
        date: today,
      ),

      // 今天的任务 - 多步骤任务
      Task(
        title: '完成季度报告',
        category: '工作',
        status: TaskStatus.inProgress,
        date: today,
        steps: 5,
        currentStep: 2,
      ),

      // 今天的任务 - 有截止日期（明天到期）
      Task(
        title: '提交项目提案',
        category: '工作',
        status: TaskStatus.todo,
        date: today,
        dueDate: tomorrow.add(const Duration(hours: 18)),
      ),

      // 今天的任务 - 逾期任务（3天前到期）
      Task(
        title: '回复客户邮件',
        category: '工作',
        status: TaskStatus.todo,
        date: today,
        dueDate: threeDaysAgo,
      ),

      // 今天的任务 - 固定工作实例
      Task(
        title: '深度工作',
        category: '工作',
        status: TaskStatus.todo,
        date: today,
        fixedWorkTemplateId: fixedWorkProvider.templates
            .where((t) => t.name == '深度工作')
            .firstOrNull
            ?.id,
        fixedWorkStages: fixedWorkProvider.templates
            .where((t) => t.name == '深度工作')
            .firstOrNull
            ?.stages,
      ),

      // 今天的任务 - 生活类
      Task(
        title: '跑步5公里',
        category: '健康',
        status: TaskStatus.todo,
        date: today,
        dueDate: today.add(const Duration(hours: 20)),
      ),

      Task(
        title: '阅读《原则》',
        category: '学习',
        status: TaskStatus.todo,
        date: today,
        steps: 3,
        currentStep: 0,
      ),

      // 昨天的已完成任务
      Task(
        title: '整理项目文档',
        category: '工作',
        status: TaskStatus.completed,
        date: yesterday,
        completedAt: yesterday.add(const Duration(hours: 16)),
      ),

      // 昨天的延迟完成任务（逾期后完成）
      Task(
        title: '审核代码',
        category: '工作',
        status: TaskStatus.completed,
        date: yesterday.subtract(const Duration(days: 2)),
        dueDate: threeDaysAgo,
        completedAt: yesterday.add(const Duration(hours: 14)),
      ),

      // 明天的任务
      Task(
        title: '参加产品评审会',
        category: '工作',
        status: TaskStatus.todo,
        date: tomorrow,
      ),

      // 无分类任务
      Task(
        title: '买牙膏',
        status: TaskStatus.todo,
        date: today,
      ),

      Task(
        title: '给妈妈打电话',
        status: TaskStatus.todo,
        date: today,
        dueDate: today.add(const Duration(hours: 21)),
      ),
    ];

    // 添加任务到 provider
    for (final task in tasks) {
      taskProvider.addTask(task);
    }
  }
}
