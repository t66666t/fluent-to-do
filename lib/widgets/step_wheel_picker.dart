import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/haptic_helper.dart';

class StepWheelPicker extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;
  final double diameter;

  const StepWheelPicker({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.diameter = 28.0,
  });

  @override
  State<StepWheelPicker> createState() => _StepWheelPickerState();
}

class _StepWheelPickerState extends State<StepWheelPicker> {
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    // Index 0 represents value 1, so index = value - 1
    _controller = FixedExtentScrollController(
      initialItem: widget.initialValue > 0 ? widget.initialValue - 1 : 0,
    );
  }

  @override
  void didUpdateWidget(StepWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      // If the value changed externally (e.g. via edit dialog), sync the wheel
      final targetIndex = widget.initialValue > 0 ? widget.initialValue - 1 : 0;
      if (_controller.hasClients && _controller.selectedItem != targetIndex) {
        _controller.jumpToItem(targetIndex);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.diameter,
      height: widget.diameter,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // Clip is needed because ListWheelScrollView paints outside bounds
      clipBehavior: Clip.antiAlias, 
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: widget.diameter,
        physics: const FixedExtentScrollPhysics(
          parent: BouncingScrollPhysics(), // Apple-style bounce
        ),
        // Visual tuning for "cylinder" effect
        diameterRatio: 1.5,
        perspective: 0.003,
        squeeze: 1.2,
        onSelectedItemChanged: (index) {
          // Index 0 is value 1
          if (index < 0) return; // Should not happen with positive index
          HapticHelper.selection();
          widget.onChanged(index + 1);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            if (index < 0) return null;
            // Steps start from 1
            final value = index + 1;
            return Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
