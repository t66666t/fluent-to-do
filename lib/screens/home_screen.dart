import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'todo_screen.dart';
import 'timer_screen.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_dialog.dart';
import '../utils/haptic_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const TodoScreen(),
    const TimerScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Watch provider to update UI when delete mode changes
    final taskProvider = context.watch<TaskProvider>();
    final isDeleteMode = taskProvider.isDeleteMode;
    final isEditMode = taskProvider.isEditMode;
    final canUndo = taskProvider.canUndo;

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
      child: Stack(
        children: [
          Scaffold(
          appBar: AppBar(
            title: Text(
              _currentIndex == 0 ? '我的任务' : '专注计时',
              style: AppTheme.titleLarge.copyWith(fontSize: 24),
            ),
            centerTitle: false,
            actions: [
              if (_currentIndex == 0) ...[
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
                       return ScaleTransition(
                         scale: anim, 
                         child: child
                       );
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
                       return ScaleTransition(
                         scale: anim, 
                         child: child
                       );
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
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              HapticHelper.selection();
              setState(() {
                _currentIndex = index;
              });
            },
            selectedItemColor: AppTheme.primaryColor,
            unselectedItemColor: AppTheme.textSecondary,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.list),
                label: 'To-Do',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.timer),
                label: '计时',
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}
