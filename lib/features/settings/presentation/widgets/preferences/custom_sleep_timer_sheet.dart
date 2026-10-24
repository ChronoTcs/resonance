import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/resonance_button.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/overlays/floating_sheet_shell.dart';

/// Canonical custom sleep timer bottom sheet built on [FloatingSheetShell]
/// and [ResonanceButton], allowing direct keyboard input and steppers for hours and minutes.
class CustomSleepTimerSheet extends StatefulWidget {
  final Duration initialDuration;
  final ValueChanged<Duration> onSave;

  const CustomSleepTimerSheet({
    super.key,
    required this.initialDuration,
    required this.onSave,
  });

  /// Displays the custom sleep timer modal sheet.
  static Future<void> show(
    BuildContext context, {
    required Duration initialDuration,
    required ValueChanged<Duration> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => CustomSleepTimerSheet(
        initialDuration: initialDuration,
        onSave: onSave,
      ),
    );
  }

  @override
  State<CustomSleepTimerSheet> createState() => _CustomSleepTimerSheetState();
}

class _CustomSleepTimerSheetState extends State<CustomSleepTimerSheet> {
  late int _hours;
  late int _minutes;
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final FocusNode _hoursFocus;
  late final FocusNode _minutesFocus;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialDuration.inHours.clamp(0, 23);
    _minutes = widget.initialDuration.inMinutes.remainder(60);
    if (_hours == 0 && _minutes == 0) {
      _minutes = 30;
    }
    _hoursController = TextEditingController(text: _hours.toString().padLeft(2, '0'));
    _minutesController = TextEditingController(text: _minutes.toString().padLeft(2, '0'));
    _hoursFocus = FocusNode();
    _minutesFocus = FocusNode();

    _hoursFocus.addListener(() {
      if (!_hoursFocus.hasFocus) {
        _formatHoursOnBlur();
      } else {
        _hoursController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _hoursController.text.length,
        );
      }
      setState(() {});
    });

    _minutesFocus.addListener(() {
      if (!_minutesFocus.hasFocus) {
        _formatMinutesOnBlur();
      } else {
        _minutesController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _minutesController.text.length,
        );
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _hoursFocus.dispose();
    _minutesFocus.dispose();
    super.dispose();
  }

  void _formatHoursOnBlur() {
    final parsed = int.tryParse(_hoursController.text) ?? 0;
    final clamped = parsed.clamp(0, 23);
    _hours = clamped;
    _hoursController.text = _hours.toString().padLeft(2, '0');
  }

  void _formatMinutesOnBlur() {
    final parsed = int.tryParse(_minutesController.text) ?? 0;
    final clamped = parsed.clamp(0, 59);
    _minutes = clamped;
    _minutesController.text = _minutes.toString().padLeft(2, '0');
  }

  void _onHoursChanged(String text) {
    if (text.isEmpty) {
      setState(() => _hours = 0);
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed != null) {
      final clamped = parsed.clamp(0, 23);
      setState(() {
        _hours = clamped;
        if (clamped != parsed) {
          _hoursController.text = clamped.toString();
          _hoursController.selection = TextSelection.fromPosition(
            TextPosition(offset: _hoursController.text.length),
          );
        }
      });
    }
  }

  void _onMinutesChanged(String text) {
    if (text.isEmpty) {
      setState(() => _minutes = 0);
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed != null) {
      final clamped = parsed.clamp(0, 59);
      setState(() {
        _minutes = clamped;
        if (clamped != parsed) {
          _minutesController.text = clamped.toString();
          _minutesController.selection = TextSelection.fromPosition(
            TextPosition(offset: _minutesController.text.length),
          );
        }
      });
    }
  }

  void _incrementHours() {
    setState(() {
      _hours = (_hours + 1 > 23 ? 0 : _hours + 1);
      _hoursController.text = _hours.toString().padLeft(2, '0');
    });
  }

  void _decrementHours() {
    setState(() {
      _hours = (_hours - 1 < 0 ? 23 : _hours - 1);
      _hoursController.text = _hours.toString().padLeft(2, '0');
    });
  }

  void _incrementMinutes() {
    setState(() {
      final next = _minutes + 5;
      _minutes = next > 59 ? 0 : next;
      _minutesController.text = _minutes.toString().padLeft(2, '0');
    });
  }

  void _decrementMinutes() {
    setState(() {
      final next = _minutes - 5;
      _minutes = next < 0 ? 55 : next;
      _minutesController.text = _minutes.toString().padLeft(2, '0');
    });
  }

  void _addQuickDuration(int additionalMinutes) {
    setState(() {
      final total = (_hours * 60 + _minutes) + additionalMinutes;
      final clamped = total.clamp(5, 23 * 60 + 59);
      _hours = clamped ~/ 60;
      _minutes = clamped % 60;
      _hoursController.text = _hours.toString().padLeft(2, '0');
      _minutesController.text = _minutes.toString().padLeft(2, '0');
    });
  }

  void _resetToDefault() {
    setState(() {
      _hours = 0;
      _minutes = 30;
      _hoursController.text = '00';
      _minutesController.text = '30';
    });
  }

  String _summaryText() {
    if (_hours == 0 && _minutes == 0) {
      return 'Please choose a duration greater than 0';
    }
    final hourPart = _hours > 0 ? '$_hours ${_hours == 1 ? 'hour' : 'hours'}' : '';
    final minPart = _minutes > 0 ? '$_minutes ${_minutes == 1 ? 'minute' : 'minutes'}' : '';
    if (hourPart.isNotEmpty && minPart.isNotEmpty) {
      return 'Playback will stop after $hourPart and $minPart';
    }
    return 'Playback will stop after ${hourPart.isNotEmpty ? hourPart : minPart}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isZero = _hours == 0 && _minutes == 0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: FloatingSheetShell(
        maxWidth: 420,
        title: 'Custom Sleep Timer',
        icon: UIcons.regular.clock,
        onClose: () => Navigator.pop(context),
        isScrollable: true,
        children: [
          Text(
            'Type numbers or use steppers to set sleep timer duration.',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Time Picker Bento Box
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hours Selector
                _buildTimeUnitSelector(
                  context,
                  label: 'HOURS',
                  controller: _hoursController,
                  focusNode: _hoursFocus,
                  textInputAction: TextInputAction.next,
                  onChanged: _onHoursChanged,
                  onIncrement: _incrementHours,
                  onDecrement: _decrementHours,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                // Minutes Selector
                _buildTimeUnitSelector(
                  context,
                  label: 'MINUTES',
                  controller: _minutesController,
                  focusNode: _minutesFocus,
                  textInputAction: TextInputAction.done,
                  onChanged: _onMinutesChanged,
                  onIncrement: _incrementMinutes,
                  onDecrement: _decrementMinutes,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Quick adjust shortcut chips
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildQuickChip('+15m', () => _addQuickDuration(15)),
              _buildQuickChip('+30m', () => _addQuickDuration(30)),
              _buildQuickChip('+1h', () => _addQuickDuration(60)),
              _buildQuickChip('30m (Default)', _resetToDefault),
            ],
          ),

          const SizedBox(height: 14),

          // Summary Text
          Center(
            child: Text(
              _summaryText(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isZero ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Bottom Action Buttons using ResonanceButton
          Row(
            children: [
              Expanded(
                child: ResonanceButton(
                  label: 'Cancel',
                  style: ResonanceButtonStyle.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ResonanceButton(
                  label: 'Set Timer',
                  icon: UIcons.regular.check,
                  style: ResonanceButtonStyle.primary,
                  onPressed: isZero
                      ? null
                      : () {
                          final dur = Duration(hours: _hours, minutes: _minutes);
                          widget.onSave(dur);
                          Navigator.pop(context);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnitSelector(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required TextInputAction textInputAction,
    required ValueChanged<String> onChanged,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    final theme = Theme.of(context);
    final isFocused = focusNode.hasFocus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReusableHoverIconButton(
          icon: UIcons.regular.angle_small_up,
          tooltip: 'Increment $label',
          iconSize: 18,
          padding: 6,
          onTap: onIncrement,
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 76,
          height: 56,
          decoration: BoxDecoration(
            color: isFocused
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.15),
              width: isFocused ? 1.5 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            textInputAction: textInputAction,
            textAlign: TextAlign.center,
            cursorColor: theme.colorScheme.primary,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isFocused ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onTap: () {
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            },
            onChanged: onChanged,
            onSubmitted: (_) {
              if (textInputAction == TextInputAction.next) {
                FocusScope.of(context).requestFocus(_minutesFocus);
              } else {
                focusNode.unfocus();
              }
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: isFocused ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        ReusableHoverIconButton(
          icon: UIcons.regular.angle_small_down,
          tooltip: 'Decrement $label',
          iconSize: 18,
          padding: 6,
          onTap: onDecrement,
        ),
      ],
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

