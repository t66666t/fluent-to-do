import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/task_rule.dart';

class RuleProvider with ChangeNotifier {
  List<TaskRule> _rules = [];

  List<TaskRule> get rules => _rules;

  RuleProvider() {
    _loadRules();
  }

  Future<void> _loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('task_rules');
    if (encodedData != null) {
      final List<dynamic> decodedData = json.decode(encodedData);
      _rules = decodedData.map((item) => TaskRule.fromJson(item)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(
      _rules.map((rule) => rule.toJson()).toList(),
    );
    await prefs.setString('task_rules', encodedData);
    notifyListeners();
  }

  void addRule(String content, List<int> activeDays, {String? name}) {
    final id = const Uuid().v4();
    final ruleName = name ?? '规则#${_rules.length + 1}';
    final newRule = TaskRule(
      id: id,
      name: ruleName,
      content: content,
      activeDays: activeDays,
    );
    _rules.add(newRule);
    _saveRules();
  }

  void updateRule(String id, String content, List<int> activeDays, {String? name}) {
    final index = _rules.indexWhere((r) => r.id == id);
    if (index != -1) {
      _rules[index] = _rules[index].copyWith(
        name: name ?? _rules[index].name,
        content: content,
        activeDays: activeDays,
      );
      _saveRules();
    }
  }

  void deleteRule(String id) {
    _rules.removeWhere((r) => r.id == id);
    _saveRules();
  }

  void toggleRule(String id) {
    final index = _rules.indexWhere((r) => r.id == id);
    if (index != -1) {
      _rules[index] = _rules[index].copyWith(
        isEnabled: !_rules[index].isEnabled,
      );
      _saveRules();
    }
  }

  void reorderRules(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final rule = _rules.removeAt(oldIndex);
    _rules.insert(newIndex, rule);
    _saveRules();
  }

  List<TaskRule> getActiveRulesForDate(DateTime date) {
    final weekday = date.weekday;
    return _rules.where((r) => r.isEnabled && r.activeDays.contains(weekday)).toList();
  }

  String getRulesTextForDate(DateTime date) {
    final enabledRules = getActiveRulesForDate(date);
    
    // Sort by index in list (already sorted as _rules is the order source)
    // Join content
    final buffer = StringBuffer();
    for (var rule in enabledRules) {
      if (buffer.isNotEmpty) {
        buffer.writeln(); // Add newline between rules
      }
      buffer.write(rule.content);
    }
    return buffer.toString();
  }

  bool hasActiveRulesForDate(DateTime date) {
    final weekday = date.weekday;
    return _rules.any((r) => r.isEnabled && r.activeDays.contains(weekday));
  }
}
