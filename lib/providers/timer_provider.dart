import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/haptic_helper.dart';

enum TimerMode { stopwatch, countdown, exam }
enum TimerState { idle, running, paused }

class TimerStyle {
  final String id;
  final String name;
  final Color backgroundColor;
  final Color circleColor;
  final Color progressColor;
  final Color textColor;
  final Color accentColor;
  final bool isDark;

  const TimerStyle({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.circleColor,
    required this.progressColor,
    required this.textColor,
    required this.accentColor,
    required this.isDark,
  });

  static const TimerStyle dark = TimerStyle(
    id: 'dark',
    name: '深色模式',
    backgroundColor: Color(0xFF0E1420),
    circleColor: Color(0xFF1C2536),
    progressColor: Color(0xFF2D66FF),
    textColor: Colors.white,
    accentColor: Color(0xFF2D66FF),
    isDark: true,
  );

  static const TimerStyle light = TimerStyle(
    id: 'light',
    name: '浅色模式',
    backgroundColor: Color(0xFFF5F7FA),
    circleColor: Color(0xFFE1E4E8),
    progressColor: Color(0xFF2D66FF),
    textColor: Color(0xFF1A1F2C),
    accentColor: Color(0xFF2D66FF),
    isDark: false,
  );

  static List<TimerStyle> get styles => [dark, light];
}

class TimerProvider with ChangeNotifier {
  TimerMode _mode = TimerMode.stopwatch;
  TimerState _state = TimerState.idle;
  Duration _currentDuration = Duration.zero;
  Duration _initialDuration = Duration.zero; // For countdown/exam progress
  Timer? _timer;
  
  // High precision timing state
  DateTime? _startTimeStamp;
  Duration _startDurationVal = Duration.zero;
  
  // Exam specific
  String? _examName;
  bool _isExamCountUp = true;
  List<ExamPreset> _examPresets = [];
  String? _activeExamPresetId;
  
  // Style
  TimerStyle _currentStyle = TimerStyle.dark;

  // Persistence keys
  static const String _prefsKeyCurrentMode = 'timer_current_mode';
  static const String _prefsKeyStyle = 'timer_style';
  static const String _prefsKeyExamPresets = 'timer_exam_presets';

  // State Cache
  final Map<TimerMode, TimerState> _cachedStates = {};
  final Map<TimerMode, Duration> _cachedDurations = {};
  final Map<TimerMode, Duration> _cachedInitialDurations = {};
  final Map<TimerMode, String?> _cachedExamNames = {};
  final Map<TimerMode, bool> _cachedExamCountUps = {};
  final Map<TimerMode, String?> _cachedExamPresetIds = {};

  TimerProvider() {
    _loadState();
  }

  // ... getters ...

  String _getModePrefix(TimerMode mode) => 'timer_${mode.index}_';

  TimerMode get mode => _mode;
  TimerState get state => _state;
  Duration get currentDuration => _currentDuration;
  Duration get initialDuration => _initialDuration;
  String? get examName => _examName;
  bool get isExamCountUp => _isExamCountUp;
  List<ExamPreset> get examPresets => _examPresets;
  String? get activeExamPresetId => _activeExamPresetId;
  TimerStyle get currentStyle => _currentStyle;

  double get progress {
    if (_mode == TimerMode.stopwatch) {
       // Cycle every 60 seconds (0.0 -> 1.0)
       return (_currentDuration.inMilliseconds % 60000) / 60000.0;
    }
    if (_initialDuration.inSeconds == 0) return 0.0;
    
    if (_mode == TimerMode.exam && _isExamCountUp) {
      // CountUp: 0.0 -> 1.0
      return _currentDuration.inMilliseconds / _initialDuration.inMilliseconds;
    }
    
    // Countdown / Exam CountDown: 1.0 -> 0.0
    return _currentDuration.inMilliseconds / _initialDuration.inMilliseconds;
  }

  Future<void> _syncWakeLock() async {
    if (_state == TimerState.running) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  void setMode(TimerMode mode) {
    if (_mode == mode) return;

    // 1. Pause/Cancel current timer
    _timer?.cancel();
    
    // 2. Save current state to cache
    _updateCache(_mode);
    
    // 3. Switch mode
    _mode = mode;
    
    // 4. Restore state from cache
    _restoreFromCache(_mode);
    
    _syncWakeLock();
    notifyListeners();
    _saveState();
  }

  void _updateCache(TimerMode mode) {
    _cachedStates[mode] = _state == TimerState.running ? TimerState.paused : _state;
    _cachedDurations[mode] = _currentDuration;
    _cachedInitialDurations[mode] = _initialDuration;
    if (mode == TimerMode.exam) {
      _cachedExamNames[mode] = _examName;
      _cachedExamCountUps[mode] = _isExamCountUp;
      _cachedExamPresetIds[mode] = _activeExamPresetId;
    }
  }

  void _restoreFromCache(TimerMode mode) {
    _state = _cachedStates[mode] ?? TimerState.idle;
    _currentDuration = _cachedDurations[mode] ?? Duration.zero;
    _initialDuration = _cachedInitialDurations[mode] ?? Duration.zero;
    
    if (mode == TimerMode.exam) {
      _examName = _cachedExamNames[mode];
      _isExamCountUp = _cachedExamCountUps[mode] ?? true;
      _activeExamPresetId = _cachedExamPresetIds[mode];
    }

    // If restored state is idle and duration is zero, reset to default defaults
    if (_state == TimerState.idle && _currentDuration == Duration.zero && _initialDuration == Duration.zero) {
        _resetDurationForMode();
    }
  }

  void setStyle(TimerStyle style) {
    _currentStyle = style;
    notifyListeners();
    _saveState();
  }

  void setCountdownDuration(Duration duration) {
    if (_state != TimerState.idle) return;
    _initialDuration = duration;
    _currentDuration = duration;
    notifyListeners();
    _saveState(); // Should save to cache? Yes, eventually
  }

  void updateCurrentDuration(Duration duration) {
    _currentDuration = duration;
    notifyListeners();
    _saveState();
  }

  void setExam(String name, Duration duration, {bool isCountUp = true}) {
    // If we are setting a new exam, we should respect the duration
    // But if we are just switching presets while idle, we assume it's a reset
    if (_state != TimerState.idle) {
       // Optional: Stop current if running?
       stopTimer();
    }
    _mode = TimerMode.exam;
    _examName = name;
    _initialDuration = duration;
    _isExamCountUp = isCountUp;
    
    if (_isExamCountUp) {
      _currentDuration = Duration.zero;
    } else {
      _currentDuration = duration;
    }
    
    notifyListeners();
    _saveState();
  }

  void addExamPreset(ExamPreset preset) {
    _examPresets.add(preset);
    notifyListeners();
    _saveState();
  }

  void updateExamPreset(ExamPreset preset) {
    final index = _examPresets.indexWhere((p) => p.id == preset.id);
    if (index == -1) return;
    _examPresets[index] = preset;
    notifyListeners();
    _saveState();
  }

  void _clearExamSelection() {
    _timer?.cancel();
    _startTimeStamp = null;
    _startDurationVal = Duration.zero;
    _state = TimerState.idle;
    _examName = null;
    _initialDuration = Duration.zero;
    _currentDuration = Duration.zero;
    _isExamCountUp = true;
    _activeExamPresetId = null;
  }

  void removeExamPreset(String id) {
    ExamPreset? removedPreset;
    for (final p in _examPresets) {
      if (p.id == id) {
        removedPreset = p;
        break;
      }
    }

    _examPresets.removeWhere((p) => p.id == id);

    final removedWasActive = removedPreset != null && _activeExamPresetId == removedPreset.id;

    if (removedWasActive || _examPresets.isEmpty) {
      _clearExamSelection();
    }
    notifyListeners();
    _saveState();
  }

  void applyExamPreset(ExamPreset preset) {
    _activeExamPresetId = preset.id;
    setExam(preset.name, preset.duration, isCountUp: preset.isCountUp);
  }

  void toggleExamCountDirection() {
    if (_mode != TimerMode.exam) return;
    
    _isExamCountUp = !_isExamCountUp;
    
    if (_state == TimerState.running || _state == TimerState.paused) {
       // Convert current duration to new mode's perspective
       // Up -> Down: New = Total - Current
       // Down -> Up: New = Total - Current
       _currentDuration = _initialDuration - _currentDuration;
       
       // Clamp to avoid float issues
       if (_currentDuration < Duration.zero) _currentDuration = Duration.zero;
       if (_currentDuration > _initialDuration) _currentDuration = _initialDuration;
       
       // Reset anchor point if running to maintain continuity
       if (_state == TimerState.running) {
          _startTimeStamp = DateTime.now();
          _startDurationVal = _currentDuration;
       }
    } else {
      // Idle state
       if (_isExamCountUp) {
          _currentDuration = Duration.zero;
       } else {
          _currentDuration = _initialDuration;
       }
    }
    
    notifyListeners();
    _saveState();
  }

  void toggleTimer() {
    if (_state == TimerState.running) {
      pauseTimer();
    } else {
      startTimer();
    }
  }

  void startTimer() {
    if (_state == TimerState.running) return;

    if (_mode == TimerMode.stopwatch) {
      // 允许从 0 开始
    } else if (_mode == TimerMode.exam && _isExamCountUp) {
      // 正计时考试：允许 currentDuration 为 0，但要求存在目标时长
      if (_initialDuration.inMilliseconds == 0) return;
    } else {
      // 倒计时或考试倒计时：不允许从 0 开始
      if (_currentDuration.inMilliseconds == 0) return;
    }

    _state = TimerState.running;
    _startTimeStamp = DateTime.now();
    _startDurationVal = _currentDuration;
    
    HapticHelper.medium();
    _syncWakeLock();
    notifyListeners();
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _tick();
    });
    _saveState();
  }

  void pauseTimer() {
    if (_state != TimerState.running) return;
    
    _state = TimerState.paused;
    _timer?.cancel();
    HapticHelper.light();
    _syncWakeLock();
    notifyListeners();
    _saveState();
  }

  void stopTimer() {
    _timer?.cancel();
    
    // Logic for completion/interruption handling
    if (_mode != TimerMode.stopwatch && _currentDuration.inSeconds == 0) {
      // Completed successfully
      HapticHelper.heavy();
    } else {
       HapticHelper.medium();
    }

    _state = TimerState.idle;
    _resetDurationForMode();
    _syncWakeLock();
    notifyListeners();
    _saveState();
  }

  void _tick() {
    if (_startTimeStamp == null) return;
    final now = DateTime.now();
    final elapsed = now.difference(_startTimeStamp!);

    if (_mode == TimerMode.stopwatch) {
      _currentDuration = _startDurationVal + elapsed;
    } else if (_mode == TimerMode.exam && _isExamCountUp) {
      _currentDuration = _startDurationVal + elapsed;
      if (_currentDuration >= _initialDuration) {
        _currentDuration = _initialDuration;
        stopTimer(); // Auto stop when reach target
        return;
      }
    } else {
      final remaining = _startDurationVal - elapsed;
      if (remaining <= Duration.zero) {
        _currentDuration = Duration.zero;
        stopTimer(); // Auto stop when done
        return;
      }
      _currentDuration = remaining;
    }
    notifyListeners();
  }

  void _resetDurationForMode() {
    if (_mode == TimerMode.stopwatch) {
      _currentDuration = Duration.zero;
      _initialDuration = Duration.zero;
    } else if (_mode == TimerMode.countdown) {
      // Keep previous set duration or default
      if (_initialDuration == Duration.zero) {
        _initialDuration = const Duration(minutes: 25);
      }
      _currentDuration = _initialDuration;
    } else if (_mode == TimerMode.exam) {
      // Keep exam duration
      _currentDuration = _isExamCountUp ? Duration.zero : _initialDuration;
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Style
    String? styleId = prefs.getString(_prefsKeyStyle);
    _currentStyle = TimerStyle.styles.firstWhere(
      (s) => s.id == styleId,
      orElse: () => TimerStyle.dark,
    );

    // Load All Modes State
    for (var m in TimerMode.values) {
      String prefix = _getModePrefix(m);
      String stateStr = prefs.getString('${prefix}state') ?? 'idle';
      TimerState s = TimerState.values.firstWhere((e) => e.toString().split('.').last == stateStr, orElse: () => TimerState.idle);
      if (s == TimerState.running) s = TimerState.paused; // Auto-pause on load
      
      _cachedStates[m] = s;
      _cachedDurations[m] = Duration(seconds: prefs.getInt('${prefix}duration') ?? 0);
      _cachedInitialDurations[m] = Duration(seconds: prefs.getInt('${prefix}initial_duration') ?? 0);
      
      if (m == TimerMode.exam) {
        _cachedExamNames[m] = prefs.getString('${prefix}exam_name');
        _cachedExamCountUps[m] = prefs.getBool('${prefix}exam_count_up') ?? true;
        _cachedExamPresetIds[m] = prefs.getString('${prefix}exam_preset_id');
      }
    }

    // Load Current Mode
    int modeIndex = prefs.getInt(_prefsKeyCurrentMode) ?? 0;
    if (modeIndex >= 0 && modeIndex < TimerMode.values.length) {
        _mode = TimerMode.values[modeIndex];
    } else {
        _mode = TimerMode.stopwatch;
    }
    
    // Load Exam Presets
    String? presetsJson = prefs.getString(_prefsKeyExamPresets);
    if (presetsJson != null) {
      try {
        List<dynamic> list = jsonDecode(presetsJson);
        _examPresets = list.map((e) => ExamPreset.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error loading exam presets: $e');
      }
    }

    final cachedActiveId = _cachedExamPresetIds[TimerMode.exam];
    if (cachedActiveId != null && !_examPresets.any((p) => p.id == cachedActiveId)) {
      _cachedExamPresetIds[TimerMode.exam] = null;
      _cachedExamNames[TimerMode.exam] = null;
      _cachedExamCountUps[TimerMode.exam] = true;
      _cachedStates[TimerMode.exam] = TimerState.idle;
      _cachedDurations[TimerMode.exam] = Duration.zero;
      _cachedInitialDurations[TimerMode.exam] = Duration.zero;
    }

    // Restore current mode state
    _restoreFromCache(_mode);

    _syncWakeLock();
    notifyListeners();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update cache for current mode first
    _updateCache(_mode);

    await prefs.setInt(_prefsKeyCurrentMode, _mode.index);
    await prefs.setString(_prefsKeyStyle, _currentStyle.id);
    
    // Save Exam Presets
    await prefs.setString(_prefsKeyExamPresets, jsonEncode(_examPresets.map((e) => e.toJson()).toList()));

    // Save all modes
    for (var m in TimerMode.values) {
       String prefix = _getModePrefix(m);
       TimerState s = _cachedStates[m] ?? TimerState.idle;
       await prefs.setString('${prefix}state', s.toString().split('.').last);
       await prefs.setInt('${prefix}duration', (_cachedDurations[m] ?? Duration.zero).inSeconds);
       await prefs.setInt('${prefix}initial_duration', (_cachedInitialDurations[m] ?? Duration.zero).inSeconds);
       
       if (m == TimerMode.exam) {
         if (_cachedExamNames[m] != null) {
            await prefs.setString('${prefix}exam_name', _cachedExamNames[m]!);
         } else {
            await prefs.remove('${prefix}exam_name');
         }
         await prefs.setBool('${prefix}exam_count_up', _cachedExamCountUps[m] ?? true);
         if (_cachedExamPresetIds[m] != null) {
            await prefs.setString('${prefix}exam_preset_id', _cachedExamPresetIds[m]!);
         } else {
            await prefs.remove('${prefix}exam_preset_id');
         }
       }
    }
  }
  
  // Public method to be called when app pauses
  void onAppPause() {
    if (_state == TimerState.running) {
      pauseTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }
}

class ExamPreset {
  final String id;
  final String name;
  final Duration duration;
  final bool isCountUp;

  ExamPreset({
    required this.id,
    required this.name,
    required this.duration,
    required this.isCountUp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'duration': duration.inSeconds,
    'isCountUp': isCountUp,
  };

  factory ExamPreset.fromJson(Map<String, dynamic> json) {
    return ExamPreset(
      id: json['id'],
      name: json['name'],
      duration: Duration(seconds: json['duration']),
      isCountUp: json['isCountUp'] ?? true,
    );
  }
}
