import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';
import '../utils/haptic_helper.dart';
import '../widgets/scale_button.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _playPauseController;
  late AnimationController _settingsController;
  late Animation<Offset> _settingsSlideAnimation;
  bool _isSettingsOpen = false;
  bool _isTimePickerVisible = false;

  final LayerLink _modeSelectorLayerLink = LayerLink();
  OverlayEntry? _modeMenuOverlay;
  late AnimationController _modeMenuController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _settingsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _settingsController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {}); // Rebuild to remove overlay
      }
    });
    _modeMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _settingsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _settingsController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playPauseController.dispose();
    _settingsController.dispose();
    _modeMenuController.dispose();
    _removeModeMenu();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      context.read<TimerProvider>().onAppPause();
    }
  }

  void _removeModeMenu() {
    _modeMenuOverlay?.remove();
    _modeMenuOverlay = null;
  }

  void _toggleModeMenu(TimerProvider provider) {
    if (_modeMenuOverlay != null) {
      _closeModeMenu();
    } else {
      _openModeMenu(provider);
    }
  }

  void _closeModeMenu() async {
    await _modeMenuController.reverse();
    _removeModeMenu();
  }

  void _openModeMenu(TimerProvider provider) {
    HapticHelper.selection();
    _modeMenuOverlay = OverlayEntry(
      builder: (context) {
        final style = provider.currentStyle;
        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeModeMenu,
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              width: 160,
              child: CompositedTransformFollower(
                link: _modeSelectorLayerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 40),
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _modeMenuController,
                    curve: Curves.easeOutBack,
                  ),
                  alignment: Alignment.topLeft,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      decoration: BoxDecoration(
                        color: style.isDark ? const Color(0xFF1C2536) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModeMenuItem(TimerMode.stopwatch, '秒表模式', provider),
                          _buildModeMenuItem(TimerMode.countdown, '倒计时模式', provider),
                          _buildModeMenuItem(TimerMode.exam, '考试模式', provider),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_modeMenuOverlay!);
    _modeMenuController.forward();
  }

  Widget _buildModeMenuItem(TimerMode mode, String label, TimerProvider provider) {
    final style = provider.currentStyle;
    final isSelected = provider.mode == mode;
    return GestureDetector(
      onTap: () {
        HapticHelper.selection();
        provider.setMode(mode);
        _closeModeMenu();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? style.accentColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? style.accentColor : style.textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 15,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Icon(Icons.check, color: style.accentColor, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleSettings() {
    HapticHelper.selection();
    setState(() {
      _isSettingsOpen = !_isSettingsOpen;
      if (_isSettingsOpen) {
        _settingsController.forward();
      } else {
        _settingsController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final timerProvider = context.watch<TimerProvider>();
    final style = timerProvider.currentStyle;

    return Scaffold(
      backgroundColor: style.backgroundColor,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              color: style.backgroundColor,
            ),
          ),
          
          // Click outside to dismiss picker
          if (_isTimePickerVisible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _isTimePickerVisible = false);
                },
                child: Container(color: Colors.transparent),
              ),
            ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, timerProvider),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(timerProvider.mode),
                      child: _buildTimerArea(context, timerProvider),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
                _buildBottomControls(context, timerProvider),
                const SizedBox(height: 60),
              ],
            ),
          ),

          // Settings Overlay
          if (_isSettingsOpen || _settingsController.isAnimating)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleSettings,
                child: Container(
                  color: Colors.transparent, // Transparent background
                  alignment: Alignment.topCenter,
                  child: SlideTransition(
                    position: _settingsSlideAnimation,
                    child: GestureDetector(
                      onTap: () {}, // Prevent tap through
                      child: _buildSettingsCard(context, timerProvider),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, TimerProvider provider) {
    final style = provider.currentStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Mode Selector
          CompositedTransformTarget(
            link: _modeSelectorLayerLink,
            child: ScaleButton(
              onTap: () => _toggleModeMenu(provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: style.circleColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getModeName(provider.mode),
                      style: TextStyle(
                        color: style.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.5).animate(_modeMenuController),
                      child: Icon(Icons.keyboard_arrow_down, color: style.textColor, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Settings Button
          ScaleButton(
            onTap: () {
              HapticHelper.selection();
              setState(() => _isSettingsOpen = true);
              _settingsController.forward();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: style.circleColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.palette_outlined, color: style.textColor),
            ),
          ),
        ],
      ),
    );
  }

  String _getModeName(TimerMode mode) {
    switch (mode) {
      case TimerMode.stopwatch: return '秒表模式';
      case TimerMode.countdown: return '倒计时模式';
      case TimerMode.exam: return '考试模式';
    }
  }

  Widget _buildTimerArea(BuildContext context, TimerProvider provider) {
    final style = provider.currentStyle;
    
    final bool showHint = provider.mode == TimerMode.countdown && 
                          provider.state == TimerState.idle && 
                          !_isTimePickerVisible;
    
    // Determine clock direction
    bool clockwise = true;
    if (provider.mode == TimerMode.countdown) {
      clockwise = false;
    } else if (provider.mode == TimerMode.exam && !provider.isExamCountUp) {
      clockwise = false;
    }

    // Determine if we show the editor (Idle OR Editing)
    final bool showEditor = provider.mode == TimerMode.countdown && 
                           (provider.state == TimerState.idle || _isTimePickerVisible);

    return SizedBox.expand(
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(300, 300),
                    painter: TimerRingPainter(
                      progress: provider.progress,
                      circleColor: style.circleColor,
                      progressColor: style.progressColor,
                      backgroundColor: style.backgroundColor,
                      clockwise: clockwise,
                    ),
                  ),
                  Positioned(
                    top: 70,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 24,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: showHint ? 1.0 : 0.0,
                        child: Center(
                          child: Text(
                            '点击设置时长',
                            style: TextStyle(
                              color: style.textColor.withValues(alpha: 0.5),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: showEditor
                        ? _buildCountdownEditor(context, provider)
                        : GestureDetector(
                            onLongPress: () {
                              if (provider.mode == TimerMode.countdown && provider.state != TimerState.idle) {
                                HapticHelper.selection();
                                provider.pauseTimer();
                                setState(() => _isTimePickerVisible = true);
                              }
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _buildTimeDisplay(provider),
                                if (provider.mode == TimerMode.exam && provider.examName != null && provider.initialDuration.inSeconds > 0)
                                  Transform.translate(
                                    offset: const Offset(0, -62),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          provider.examName!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: provider.currentStyle.textColor.withValues(alpha: 0.72),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatHms(provider.initialDuration),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: provider.currentStyle.textColor.withValues(alpha: 0.55),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 70,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: provider.mode == TimerMode.exam
                            ? _buildExamControls(context, provider)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: style.accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    provider.state == TimerState.running ? '保持专注' : '准备开始',
                                    style: TextStyle(
                                      color: style.textColor.withValues(alpha: 0.7),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (provider.mode == TimerMode.exam)
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: SizedBox(
                height: 44,
                child: _buildExamPresetSelector(context, provider),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCountdownEditor(BuildContext context, TimerProvider provider) {
    final style = provider.currentStyle;
    final isIdle = provider.state == TimerState.idle;
    
    // If Idle, we edit initialDuration. If Running/Paused, we edit currentDuration.
    final initialValue = isIdle ? provider.initialDuration : provider.currentDuration;
    final onDurationChanged = isIdle ? provider.setCountdownDuration : provider.updateCurrentDuration;

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      firstChild: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticHelper.selection();
          setState(() => _isTimePickerVisible = true);
        },
        child: _buildTimeDisplay(provider),
      ),
      secondChild: SizedBox(
        height: 200,
        width: 260,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(
                      color: style.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hms,
                  initialTimerDuration: initialValue,
                  onTimerDurationChanged: (val) {
                    if (val.inSeconds > 0) onDurationChanged(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            ScaleButton(
              onTap: () {
                HapticHelper.selection();
                setState(() => _isTimePickerVisible = false);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: style.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '完成',
                  style: TextStyle(
                    color: style.accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      crossFadeState: _isTimePickerVisible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
    );
  }

  Widget _buildTimeDisplay(TimerProvider provider) {
    final duration = provider.currentDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    // Always show HH:MM:SS format
    final timeStr = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return SizedBox(
      height: 96,
      child: Center(
        child: Text(
          timeStr,
          style: GoogleFonts.inter(
            color: provider.currentStyle.textColor,
            fontSize: 56,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: -2,
          ),
        ),
      ),
    );
  }

  String _formatHms(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }


  
  Widget _buildExamPresetSelector(BuildContext context, TimerProvider provider) {
    final style = provider.currentStyle;
    final presets = provider.examPresets;
    
    // Calculate width to fit nicely
    // If it's outside, maybe we can make it wider
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: Center(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: presets.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            if (index == presets.length) {
              // Add Button
              return ScaleButton(
                onTap: () => _showPresetDialog(context, provider),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: style.circleColor.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: style.textColor.withValues(alpha: 0.1), width: 1),
                  ),
                  child: Icon(Icons.add, size: 20, color: style.textColor),
                ),
              );
            }
            
            final preset = presets[index];
            final isActive = provider.activeExamPresetId != null
                ? provider.activeExamPresetId == preset.id
                : (provider.examName == preset.name && provider.initialDuration == preset.duration);
                             
            return ScaleButton(
              onTap: () {
                HapticHelper.selection();
                _showPresetDialog(context, provider, preset: preset);
              },
              onLongPress: () {
                HapticHelper.medium();
                _showDeletePresetDialog(context, provider, preset);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? style.accentColor : style.circleColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isActive ? style.accentColor : style.textColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  preset.name,
                  style: TextStyle(
                    color: isActive ? Colors.white : style.textColor.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Unused legacy dialog - removed
  // void _showExamDialog(BuildContext context, TimerProvider provider) { ... }

  Widget _buildBottomControls(BuildContext context, TimerProvider provider) {
    final style = provider.currentStyle;
    final isRunning = provider.state == TimerState.running;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Reset Button (Left)
        ScaleButton(
          onTap: () {
            HapticHelper.medium();
            setState(() => _isTimePickerVisible = false); // Ensure picker is closed on reset
            provider.stopTimer();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: style.textColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Icon(Icons.refresh, color: style.textColor, size: 24),
          ),
        ),

        // Play/Pause Button (Center)
        GestureDetector(
          onLongPress: () {
            // Long press to stop/finish
            if (provider.state != TimerState.idle) {
              HapticHelper.heavy();
              provider.stopTimer();
            }
          },
          onTap: () {
             setState(() => _isTimePickerVisible = false);
             if (provider.mode == TimerMode.exam && provider.state == TimerState.idle) {
               if (provider.examName == null || provider.initialDuration.inSeconds == 0) {
                 HapticHelper.selection();
                 _showSelectExamFirstDialog(context, provider);
                 return;
               }
               _startExamWithCountdown(context, provider);
             } else {
               provider.toggleTimer();
             }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: style.accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: style.accentColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              isRunning ? Icons.pause : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),

        // Dummy Placeholder for Symmetry (Right)
        const SizedBox(width: 48 + 4, height: 48 + 4), 
      ],
    );
  }
  
  void _startExamWithCountdown(BuildContext context, TimerProvider provider) {
     // Show 3-2-1 overlay then start
     // Using a temporary dialog or overlay
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (ctx) => _CountdownOverlay(onFinished: () {
         Navigator.pop(ctx);
         provider.startTimer();
       }),
     );
  }

  void _showSelectExamFirstDialog(BuildContext context, TimerProvider provider) {
    final style = provider.currentStyle;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('请选择考试'),
        content: const Text('开始前请先选择或创建一个考试预设。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _showPresetDialog(context, provider);
            },
            child: Text(
              '新建预设',
              style: TextStyle(color: style.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamControls(BuildContext context, TimerProvider provider) {
    final style = provider.currentStyle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle Direction Button
        ScaleButton(
          onTap: () {
             HapticHelper.selection();
             provider.toggleExamCountDirection();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: style.circleColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  provider.isExamCountUp ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14, 
                  color: style.textColor
                ),
                const SizedBox(width: 4),
                Text(
                  provider.isExamCountUp ? '正计时' : '倒计时',
                  style: TextStyle(
                    color: style.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDeletePresetDialog(BuildContext context, TimerProvider provider, ExamPreset preset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: provider.currentStyle.backgroundColor,
        title: Text('删除预设', style: TextStyle(color: provider.currentStyle.textColor)),
        content: Text('确定要删除 "${preset.name}" 吗？', style: TextStyle(color: provider.currentStyle.textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              provider.removeExamPreset(preset.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPresetDialog(BuildContext context, TimerProvider provider, {ExamPreset? preset}) {
    final style = provider.currentStyle;
    final nameController = TextEditingController(text: preset?.name ?? '考试 #${provider.examPresets.length + 1}');
    Duration duration = preset?.duration ?? const Duration(minutes: 60);
    bool isCountUp = preset?.isCountUp ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setState) {
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
          final sheetBg = style.isDark ? const Color(0xFF1C2536) : Colors.white;

          void save({required bool apply}) {
            final name = nameController.text.trim();
            if (name.isEmpty || duration.inSeconds <= 0) return;
            final updated = ExamPreset(
              id: preset?.id ?? DateTime.now().toIso8601String(),
              name: name,
              duration: duration,
              isCountUp: isCountUp,
            );
            if (preset == null) {
              provider.addExamPreset(updated);
            } else {
              provider.updateExamPreset(updated);
            }
            if (apply) {
              provider.applyExamPreset(updated);
            }
            Navigator.pop(sheetContext);
          }

          return SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 16 + bottomInset),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: style.textColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        preset == null ? '新建预设' : '编辑预设',
                        style: TextStyle(
                          color: style.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Icon(CupertinoIcons.xmark, size: 18, color: style.textColor.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: style.textColor),
                    decoration: InputDecoration(
                      labelText: '名称',
                      labelStyle: TextStyle(color: style.textColor.withValues(alpha: 0.6)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: style.textColor.withValues(alpha: 0.25)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: style.accentColor.withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 170,
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        textTheme: CupertinoTextThemeData(
                          pickerTextStyle: TextStyle(color: style.textColor, fontSize: 18),
                        ),
                      ),
                      child: CupertinoTimerPicker(
                        mode: CupertinoTimerPickerMode.hms,
                        initialTimerDuration: duration,
                        onTimerDurationChanged: (val) {
                          setState(() => duration = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '默认计时',
                        style: TextStyle(color: style.textColor.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      CupertinoSlidingSegmentedControl<int>(
                        groupValue: isCountUp ? 0 : 1,
                        children: {
                          0: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text('正计时', style: TextStyle(color: style.textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          1: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text('倒计时', style: TextStyle(color: style.textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        },
                        onValueChanged: (val) {
                          if (val == null) return;
                          setState(() => isCountUp = val == 0);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: style.textColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text('取消', style: TextStyle(color: style.textColor, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: style.textColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () => save(apply: false),
                          child: Text('保存', style: TextStyle(color: style.textColor, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: style.accentColor,
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () => save(apply: true),
                          child: const Text('应用', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, TimerProvider provider) {
    final style = provider.currentStyle;
    return Container(
      margin: const EdgeInsets.only(top: 0),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: style.backgroundColor, // Or a slightly different shade
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('风格设置', style: TextStyle(color: style.textColor, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: TimerStyle.styles.map((s) => _buildStyleOption(provider, s)).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStyleOption(TimerProvider provider, TimerStyle s) {
    final isSelected = provider.currentStyle.id == s.id;
    final style = provider.currentStyle;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticHelper.selection();
          provider.setStyle(s);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? style.accentColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? style.accentColor : style.textColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: s.backgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: style.textColor.withValues(alpha: 0.2), width: 1),
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                s.name,
                style: TextStyle(
                  color: isSelected ? style.accentColor : style.textColor,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(Icons.check, color: style.accentColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class TimerRingPainter extends CustomPainter {
  final double progress;
  final Color circleColor;
  final Color progressColor;
  final Color backgroundColor;
  final bool clockwise;

  TimerRingPainter({
    required this.progress,
    required this.circleColor,
    required this.progressColor,
    required this.backgroundColor,
    this.clockwise = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;

    // Background Circle
    final bgPaint = Paint()
      ..color = circleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress Arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // Start from top (-pi/2)
    double sweepAngle = 2 * pi * progress;
    if (!clockwise) {
      sweepAngle = -sweepAngle;
    }
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.circleColor != circleColor ||
           oldDelegate.progressColor != progressColor ||
           oldDelegate.clockwise != clockwise;
  }
}

class _CountdownOverlay extends StatefulWidget {
  final VoidCallback onFinished;
  const _CountdownOverlay({required this.onFinished});

  @override
  State<_CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<_CountdownOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  int _count = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.5).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _startCount();
  }
  
  void _startCount() async {
    for (int i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => _count = i);
      HapticHelper.medium();
      _controller.reset();
      await _controller.forward();
    }
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnim.value,
              child: Opacity(
                opacity: _opacityAnim.value,
                child: Text(
                  '$_count',
                  style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
