import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/fixed_work_provider.dart';
import '../models/fixed_work.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';

/// 固定工作编辑器
class FixedWorkEditor extends StatefulWidget {
  final FixedWorkTemplate? template;
  
  const FixedWorkEditor({super.key, this.template});

  @override
  State<FixedWorkEditor> createState() => _FixedWorkEditorState();
}

class _FixedWorkEditorState extends State<FixedWorkEditor> {
  final _nameController = TextEditingController();
  final List<_StageData> _stages = [];
  
  @override
  void initState() {
    super.initState();
    
    if (widget.template != null) {
      // 编辑现有模板
      _nameController.text = widget.template!.name;
      _stages.addAll(
        widget.template!.stages.map((s) => _StageData(
          name: s.name,
          type: s.type,
          duration: s.duration,
          maxDuration: s.maxDuration,
        )),
      );
    } else {
      // 新建模板，添加一个默认阶段
      _stages.add(_StageData(
        name: '阶段 1',
        type: StageType.point,
        duration: 1800, // 30分钟
      ));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.template == null ? '新建固定工作' : '编辑固定工作'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _canSave() ? _save : null,
            child: Text(
              '保存',
              style: TextStyle(
                color: _canSave() ? AppTheme.primaryColor : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模板名称
            _buildNameField(),
            const SizedBox(height: 24),
            
            // 阶段列表
            _buildStageList(),
            const SizedBox(height: 16),
            
            // 添加阶段按钮
            _buildAddStageButton(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '模板名称',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: '输入模板名称',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildStageList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '工作阶段',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '共 ${_stages.length} 个阶段',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        ...List.generate(_stages.length, (index) {
          return _buildStageCard(index);
        }),
      ],
    );
  }

  Widget _buildStageCard(int index) {
    final stage = _stages[index];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: stage.nameController,
                    decoration: const InputDecoration(
                      hintText: '阶段名称',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (value) {
                      stage.name = value;
                      setState(() {});
                    },
                  ),
                ),
                if (_stages.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      HapticHelper.light();
                      setState(() {
                        _stages.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 阶段类型选择
            Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    label: '点式',
                    icon: Icons.circle,
                    isSelected: stage.type == StageType.point,
                    onTap: () {
                      setState(() {
                        stage.type = StageType.point;
                        stage.maxDuration = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTypeButton(
                    label: '区间式',
                    icon: Icons.timelapse,
                    isSelected: stage.type == StageType.range,
                    onTap: () {
                      setState(() {
                        stage.type = StageType.range;
                        stage.maxDuration = stage.duration + 600; // 默认+10分钟
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 时长设置
            if (stage.type == StageType.point)
              _buildDurationField('时长', stage.durationController, (value) {
                stage.duration = value;
                setState(() {});
              })
            else ...[
              _buildDurationField('最小时长', stage.durationController, (value) {
                stage.duration = value;
                setState(() {});
              }),
              const SizedBox(height: 8),
              _buildDurationField('最大时长', stage.maxDurationController!, (value) {
                stage.maxDuration = value;
                setState(() {});
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationField(
    String label,
    TextEditingController controller,
    Function(int) onChanged,
  ) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '分钟',
              suffixText: '分钟',
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              final minutes = int.tryParse(value) ?? 0;
              onChanged(minutes * 60);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddStageButton() {
    return InkWell(
      onTap: () {
        HapticHelper.light();
        setState(() {
          _stages.add(_StageData(
            name: '阶段 ${_stages.length + 1}',
            type: StageType.point,
            duration: 1800,
          ));
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text(
              '添加阶段',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canSave() {
    if (_nameController.text.trim().isEmpty) return false;
    if (_stages.isEmpty) return false;
    
    for (final stage in _stages) {
      if (stage.name.trim().isEmpty) return false;
      if (stage.duration <= 0) return false;
      if (stage.type == StageType.range) {
        if (stage.maxDuration == null || stage.maxDuration! <= stage.duration) {
          return false;
        }
      }
    }
    
    return true;
  }

  void _save() {
    if (!_canSave()) return;
    
    final stages = _stages.map((s) => Stage(
      name: s.name.trim(),
      type: s.type,
      duration: s.duration,
      maxDuration: s.maxDuration,
    )).toList();
    
    final template = FixedWorkTemplate(
      id: widget.template?.id,
      name: _nameController.text.trim(),
      stages: stages,
      createdAt: widget.template?.createdAt,
    );
    
    final provider = context.read<FixedWorkProvider>();
    if (widget.template == null) {
      provider.addTemplate(template);
    } else {
      provider.updateTemplate(template.id, template);
    }
    
    HapticHelper.medium();
    Navigator.pop(context);
  }
}

class _StageData {
  String name;
  StageType type;
  int duration;
  int? maxDuration;
  
  late final TextEditingController nameController;
  late final TextEditingController durationController;
  TextEditingController? maxDurationController;
  
  _StageData({
    required this.name,
    required this.type,
    required this.duration,
    this.maxDuration,
  }) {
    nameController = TextEditingController(text: name);
    durationController = TextEditingController(text: '${duration ~/ 60}');
    if (maxDuration != null) {
      maxDurationController = TextEditingController(text: '${maxDuration! ~/ 60}');
    }
  }
}
