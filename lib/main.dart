import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/task_provider.dart';
import 'providers/rule_provider.dart';
import 'providers/timer_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  final initialTab = prefs.getInt('last_tab_index') ?? 0;
  runApp(MyApp(initialIndex: initialTab));
}

class MyApp extends StatelessWidget {
  final int initialIndex;
  const MyApp({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RuleProvider()),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProxyProvider<RuleProvider, TaskProvider>(
          create: (_) => TaskProvider(),
          update: (_, ruleProvider, taskProvider) =>
              taskProvider!..updateRuleProvider(ruleProvider),
        ),
      ],
      child: MaterialApp(
        title: 'Fluent ToDo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: HomeScreen(initialIndex: initialIndex),
      ),
    );
  }
}
