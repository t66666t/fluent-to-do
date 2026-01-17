import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  
  late AnimationController _settingsController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isSettingsOpen = false;

  final List<Widget> _screens = [
    const TodoScreen(),
    const TimerScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    _settingsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _settingsController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _settingsController,
      curve: Curves.easeOut,
    );
  }
  
  @override
  void dispose() {
    _settingsController.dispose();
    super.dispose();
  }
  
  void _toggleSettings() {
    HapticHelper.light();
    if (_isSettingsOpen) {
      _settingsController.reverse();
      setState(() {
        _isSettingsOpen = false;
      });
    } else {
      setState(() {
        _isSettingsOpen = true;
      });
      _settingsController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to update UI when delete mode changes
    final isDeleteMode = context.watch<TaskProvider>().isDeleteMode;

    return Stack(
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
                IconButton(
                  icon: Icon(
                    isDeleteMode ? Icons.delete : Icons.delete_outline,
                    color: isDeleteMode ? AppTheme.errorColor : Colors.black54,
                  ),
                  onPressed: () {
                    HapticHelper.medium();
                    context.read<TaskProvider>().toggleDeleteMode();
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
        
        // Custom Settings Overlay
        AnimatedBuilder(
          animation: _settingsController,
          builder: (context, child) {
            if (_settingsController.status == AnimationStatus.dismissed && !_isSettingsOpen) {
              return const SizedBox.shrink();
            }
            
            return Stack(
               children: [
                 // 1. Full Screen Blur & Dimming (Click to close)
                 Positioned.fill(
                   child: FadeTransition(
                     opacity: _fadeAnimation,
                     child: GestureDetector(
                       onTap: _toggleSettings,
                       behavior: HitTestBehavior.opaque,
                       child: BackdropFilter(
                         filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                         child: Container(
                           color: Colors.black.withValues(alpha: 0.2),
                         ),
                       ),
                     ),
                   ),
                 ),
                 
                 // 2. Settings Dialog
                 Positioned.fill(
                   child: Center(
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SettingsDialog(
                            onClose: _toggleSettings,
                          ),
                        ),
                      ),
                    ),
                 ),
                 
                 // 3. Fake Toggle Button (Keeps interaction alive)
                if (_currentIndex == 0)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 4, // Center vertically in standard AppBar (56-48)/2 = 4
                    right: 16,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.black54),
                        onPressed: _toggleSettings,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
