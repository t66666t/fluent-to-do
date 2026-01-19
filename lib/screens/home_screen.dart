import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'todo_screen.dart';
import 'timer_screen.dart';
import '../providers/task_provider.dart';
import '../providers/timer_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_dialog.dart';
import '../utils/haptic_helper.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  static const String _kLastTabIndex = 'last_tab_index';
  
  // Note: We don't use const List here because we want to rebuild based on state if needed,
  // but simpler to just use switch in build or IndexedStack.
  // For AnimatedSwitcher, we need unique keys.
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  Future<void> _persistCurrentTab() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastTabIndex, _currentIndex);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _persistCurrentTab();
    }
  }
  
  void _toggleSettings() {
    HapticHelper.light();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (ctx, anim, secAnim) => const SettingsDialog(),
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
  }

  PreferredSizeWidget _buildTodoAppBar(BuildContext context, TaskProvider taskProvider) {
    final isDeleteMode = taskProvider.isDeleteMode;
    final isEditMode = taskProvider.isEditMode;
    final canUndo = taskProvider.canUndo;

    return AppBar(
      title: Text(
        '我的任务',
        style: AppTheme.titleLarge.copyWith(fontSize: 24),
      ),
      centerTitle: false,
      backgroundColor: Colors.transparent,
      actions: [
        // Undo Button
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: (isDeleteMode && canUndo)
              ? IconButton(
                  icon: const Icon(Icons.undo, color: AppTheme.textPrimary),
                  onPressed: () {
                    HapticHelper.medium();
                    context.read<TaskProvider>().undoLastDelete();
                  },
                )
              : const SizedBox.shrink(),
        ),
        // Delete Button
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) {
              return ScaleTransition(scale: anim, child: child);
            },
            switchInCurve: Curves.elasticOut,
            switchOutCurve: Curves.easeIn,
            child: Icon(
              isDeleteMode ? Icons.delete : Icons.delete_outline,
              key: ValueKey('del_$isDeleteMode'),
              color: isDeleteMode ? AppTheme.errorColor : Colors.black54,
            ),
          ),
          onPressed: () {
            HapticHelper.medium();
            context.read<TaskProvider>().toggleDeleteMode();
          },
        ),
        // Edit Button
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) {
              return ScaleTransition(scale: anim, child: child);
            },
            switchInCurve: Curves.elasticOut,
            switchOutCurve: Curves.easeIn,
            child: Icon(
              isEditMode ? Icons.edit : Icons.edit_outlined,
              key: ValueKey('edit_$isEditMode'),
              color: isEditMode ? AppTheme.primaryColor : Colors.black54,
            ),
          ),
          onPressed: () {
            HapticHelper.medium();
            context.read<TaskProvider>().toggleEditMode();
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: const Icon(Icons.settings, color: Colors.black54),
            onPressed: _toggleSettings,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to update UI when delete mode changes
    final taskProvider = context.watch<TaskProvider>();
    final timerProvider = context.watch<TimerProvider>();
    
    final isDeleteMode = taskProvider.isDeleteMode;
    final isEditMode = taskProvider.isEditMode;
    
    // Determine Styles based on active tab
    final bool isTimerTab = _currentIndex == 1;
    final timerStyle = timerProvider.currentStyle;
    
    // Smooth transition colors
    final Color scaffoldBgColor = isTimerTab ? timerStyle.backgroundColor : AppTheme.backgroundColor;
    final Color navBarBgColor = isTimerTab ? timerStyle.backgroundColor : Colors.white;
    final Color navBarSelectedColor = isTimerTab ? timerStyle.accentColor : AppTheme.primaryColor;
    final Color navBarUnselectedColor = isTimerTab ? timerStyle.textColor.withValues(alpha: 0.5) : AppTheme.textSecondary;

    return PopScope(
      canPop: !isDeleteMode && !isEditMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (isDeleteMode) {
          context.read<TaskProvider>().setDeleteMode(false);
          return;
        }

        if (isEditMode) {
          context.read<TaskProvider>().toggleEditMode();
          return;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        color: scaffoldBgColor,
        child: Scaffold(
          backgroundColor: Colors.transparent, // Use AnimatedContainer background
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
               return FadeTransition(
                 opacity: animation,
                 child: child,
               );
            },
            child: _currentIndex == 0 
                ? Scaffold(
                    key: const ValueKey('todo_scaffold'),
                    backgroundColor: Colors.transparent,
                    appBar: _buildTodoAppBar(context, taskProvider),
                    body: const TodoScreen(key: ValueKey('todo')),
                  )
                : const TimerScreen(key: ValueKey('timer')),
          ),
          bottomNavigationBar: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: navBarBgColor,
              border: Border(
                top: BorderSide(
                  color: isTimerTab ? timerStyle.textColor.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                  width: 0.5,
                ),
              ),
              boxShadow: [
                if (!isTimerTab) // Only show shadow in light mode for depth
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
              ]
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  if (_currentIndex != index) {
                    HapticHelper.selection();
                    setState(() {
                      _currentIndex = index;
                    });
                    _persistCurrentTab();
                  }
                },
                backgroundColor: Colors.transparent, // Handled by AnimatedContainer
                elevation: 0,
                selectedItemColor: navBarSelectedColor,
                unselectedItemColor: navBarUnselectedColor,
                type: BottomNavigationBarType.fixed,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                items: [
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Icon(_currentIndex == 0 ? Icons.task_alt : Icons.task_alt_outlined),
                    ),
                    label: 'To-Do',
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Icon(_currentIndex == 1 ? Icons.timer : Icons.timer_outlined),
                    ),
                    label: '计时',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
