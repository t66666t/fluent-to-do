import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/task_provider.dart';
import 'providers/rule_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/fixed_work_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'utils/demo_data_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  final initialTab = prefs.getInt('last_tab_index') ?? 0;
  
  runApp(MyApp(initialIndex: initialTab));
}

class MyApp extends StatefulWidget {
  final int initialIndex;
  const MyApp({super.key, this.initialIndex = 0});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 延迟加载示例数据，确保 Provider 已初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoadDemoDataIfNeeded(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RuleProvider()),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => FixedWorkProvider()),
        ChangeNotifierProxyProvider2<RuleProvider, FixedWorkProvider, TaskProvider>(
          create: (_) => TaskProvider(),
          update: (_, ruleProvider, fixedWorkProvider, taskProvider) =>
              taskProvider!
                ..updateRuleProvider(ruleProvider)
                ..updateFixedWorkProvider(fixedWorkProvider),
        ),
      ],
      child: MaterialApp(
        title: 'Fluent ToDo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: HomeScreen(initialIndex: widget.initialIndex),
      ),
    );
  }
}

/// 自动加载示例数据（仅首次且数据为空时）
Future<void> _autoLoadDemoDataIfNeeded(BuildContext context) async {
  // 检查是否已加载过
  if (await DemoDataLoader.hasDemoDataLoaded()) {
    return;
  }

  // 检查是否有现有数据
  final taskProvider = context.read<TaskProvider>();
  if (taskProvider.tasks.isNotEmpty) {
    // 有数据，标记为已加载（避免以后再提示）
    await DemoDataLoader.markDemoDataLoaded();
    return;
  }

  // 数据为空，自动加载示例数据
  final ruleProvider = context.read<RuleProvider>();
  final fixedWorkProvider = context.read<FixedWorkProvider>();
  
  await DemoDataLoader.loadDemoData(
    taskProvider,
    ruleProvider,
    fixedWorkProvider,
    clearExisting: false,
  );
}
