import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fixed_work.dart';

/// 固定工作 Provider - 管理固定工作模板和计时会话
class FixedWorkProvider with ChangeNotifier {
  List<FixedWorkTemplate> _templates = [];
  FixedWorkSession? _currentSession;
  Timer? _sessionTimer;
  
  List<FixedWorkTemplate> get templates => _templates;
  FixedWorkSession? get currentSession => _currentSession;
  bool get hasActiveSession => _currentSession != null && !_currentSession!.isCompleted;
  
  FixedWorkProvider() {
    _loadData();
  }
  
  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
  
  /// 添加新模板
  void addTemplate(FixedWorkTemplate template) {
    _templates.add(template);
    _saveTemplates();
    notifyListeners();
  }
  
  /// 更新模板
  void updateTemplate(String id, FixedWorkTemplate updatedTemplate) {
    final index = _templates.indexWhere((t) => t.id == id);
    if (index != -1) {
      _templates[index] = updatedTemplate;
      _saveTemplates();
      notifyListeners();
    }
  }
  
  /// 删除模板
  void deleteTemplate(String id) {
    _templates.removeWhere((t) => t.id == id);
    _saveTemplates();
    notifyListeners();
  }
  
  /// 开始新的计时会话
  void startSession(FixedWorkTemplate template) {
    // 如果有正在进行的会话，先结束它
    if (_currentSession != null && !_currentSession!.isCompleted) {
      finishSession();
    }
    
    _currentSession = FixedWorkSession(
      templateId: template.id,
      templateName: template.name,
      stages: List<Stage>.from(template.stages), // 创建阶段快照
    );
    
    _startSessionTimer();
    _saveSession();
    notifyListeners();
  }
  
  /// 暂停会话
  void pauseSession() {
    if (_currentSession == null || _currentSession!.isPaused) return;
    
    _currentSession = _currentSession!.copyWith(
      isPaused: true,
      lastPauseTime: DateTime.now(),
    );
    
    _sessionTimer?.cancel();
    _saveSession();
    notifyListeners();
  }
  
  /// 恢复会话
  void resumeSession() {
    if (_currentSession == null || !_currentSession!.isPaused) return;
    
    // 计算暂停时长
    final pauseDuration = DateTime.now().difference(_currentSession!.lastPauseTime!).inSeconds;
    
    _currentSession = _currentSession!.copyWith(
      isPaused: false,
      clearLastPauseTime: true,
      totalPausedDuration: _currentSession!.totalPausedDuration + pauseDuration,
    );
    
    _startSessionTimer();
    _saveSession();
    notifyListeners();
  }
  
  /// 进入下一阶段
  void nextStage() {
    if (_currentSession == null) return;
    
    final nextIndex = _currentSession!.currentStageIndex + 1;
    if (nextIndex >= _currentSession!.stages.length) {
      // 已经是最后一个阶段，完成会话
      finishSession();
      return;
    }
    
    _currentSession = _currentSession!.copyWith(
      currentStageIndex: nextIndex,
      currentStageElapsed: 0,
    );
    
    _saveSession();
    notifyListeners();
  }
  
  /// 完成会话
  void finishSession() {
    if (_currentSession == null) return;
    
    _currentSession = _currentSession!.copyWith(
      endTime: DateTime.now(),
    );
    
    _sessionTimer?.cancel();
    _saveSession();
    notifyListeners();
  }
  
  /// 取消会话
  void cancelSession() {
    _currentSession = null;
    _sessionTimer?.cancel();
    _clearSession();
    notifyListeners();
  }
  
  /// 启动会话定时器
  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSession == null || _currentSession!.isPaused) {
        timer.cancel();
        return;
      }
      
      // 更新当前阶段已用时间
      _currentSession = _currentSession!.copyWith(
        currentStageElapsed: _currentSession!.currentStageElapsed + 1,
      );
      
      notifyListeners();
      
      // 每10秒保存一次（避免频繁IO）
      if (_currentSession!.currentStageElapsed % 10 == 0) {
        _saveSession();
      }
    });
  }
  
  /// 持久化模板
  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final data = json.encode(_templates.map((t) => t.toJson()).toList());
    await prefs.setString('fixed_work_templates', data);
  }
  
  /// 持久化会话
  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentSession != null) {
      final data = json.encode(_currentSession!.toJson());
      await prefs.setString('fixed_work_session', data);
    } else {
      await prefs.remove('fixed_work_session');
    }
  }
  
  /// 清除会话
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fixed_work_session');
  }
  
  /// 加载数据
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 加载模板
    final templatesData = prefs.getString('fixed_work_templates');
    if (templatesData != null) {
      final List<dynamic> decoded = json.decode(templatesData);
      _templates = decoded.map((t) => FixedWorkTemplate.fromJson(t)).toList();
    }
    
    // 加载会话（支持崩溃恢复）
    final sessionData = prefs.getString('fixed_work_session');
    if (sessionData != null) {
      try {
        _currentSession = FixedWorkSession.fromJson(json.decode(sessionData));
        
        // 如果会话未完成且未暂停，恢复定时器
        if (!_currentSession!.isCompleted && !_currentSession!.isPaused) {
          _startSessionTimer();
        }
      } catch (e) {
        // 如果加载失败，清除损坏的会话
        await _clearSession();
      }
    }
    
    notifyListeners();
  }
}
