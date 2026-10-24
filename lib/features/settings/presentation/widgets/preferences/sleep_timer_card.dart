import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/resonance_button.dart';
import 'package:resonance/core/widgets/inputs/resonance_switch.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/providers/sleep_timer_provider.dart';

import 'custom_sleep_timer_sheet.dart';
import 'sleep_timer_countdown_text.dart';

/// Card containing all Sleep Timer controls, presets, and fade-out toggles.
/// Uses granular Riverpod selectors to completely avoid rebuilds during active countdown ticks.
class SleepTimerCard extends ConsumerWidget {
  const SleepTimerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Granular selectors: strictly decoupled from 1-second ticking remainingDuration
    final isEnabled = ref.watch(sleepTimerProvider.select((s) => s.isEnabled));
    final selectedMode = ref.watch(sleepTimerProvider.select((s) => s.selectedMode));
    final selectedDuration = ref.watch(sleepTimerProvider.select((s) => s.selectedDuration));
    final fadeOutEnabled = ref.watch(sleepTimerProvider.select((s) => s.fadeOutEnabled));
    final hasCurrentTrack = ref.watch(audioProvider.select((s) => s.currentTrack != null));

    final isEndOfTrack = isEnabled && selectedMode == SleepTimerMode.endOfTrack;
    final isDurationMode = isEnabled && selectedMode == SleepTimerMode.duration;
    final isCustomPreset = selectedMode == SleepTimerMode.duration &&
        ![15, 30, 45, 60].contains(selectedDuration.inMinutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sleep Timer',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header status & Master Toggle
                Row(
                  children: [
                    Icon(
                      UIcons.regular.moon,
                      size: 18,
                      color: isEnabled
                          ? theme.primaryColor
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEnabled ? 'Sleep Timer Active' : 'Sleep Timer',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isEnabled)
                            if (isEndOfTrack)
                              Text(
                                'Stopping at end of current track',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.primaryColor,
                                ),
                              )
                            else
                              SleepTimerCountdownText(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.primaryColor,
                                ),
                              )
                          else
                            Text(
                              'Select duration and toggle switch to activate',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isEnabled && !AppBreakpoints.isCompact(context)) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: isEndOfTrack
                            ? Text(
                                'End of Track',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              )
                            : SleepTimerCountdownText(
                                showRemainingSuffix: false,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    ResonanceSwitch(
                      value: isEnabled,
                      onChanged: (val) {
                        if (val && selectedMode == SleepTimerMode.endOfTrack && !hasCurrentTrack) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Start playing a track to use End of Track mode.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        ref.read(sleepTimerProvider.notifier).setEnabled(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Presets wrap
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetChip(
                      context,
                      label: '15 min',
                      isSelected: selectedMode == SleepTimerMode.duration &&
                          selectedDuration == const Duration(minutes: 15),
                      onTap: () => ref
                          .read(sleepTimerProvider.notifier)
                          .selectDuration(const Duration(minutes: 15)),
                    ),
                    _buildPresetChip(
                      context,
                      label: '30 min',
                      isSelected: selectedMode == SleepTimerMode.duration &&
                          selectedDuration == const Duration(minutes: 30),
                      onTap: () => ref
                          .read(sleepTimerProvider.notifier)
                          .selectDuration(const Duration(minutes: 30)),
                    ),
                    _buildPresetChip(
                      context,
                      label: '45 min',
                      isSelected: selectedMode == SleepTimerMode.duration &&
                          selectedDuration == const Duration(minutes: 45),
                      onTap: () => ref
                          .read(sleepTimerProvider.notifier)
                          .selectDuration(const Duration(minutes: 45)),
                    ),
                    _buildPresetChip(
                      context,
                      label: '60 min',
                      isSelected: selectedMode == SleepTimerMode.duration &&
                          selectedDuration == const Duration(minutes: 60),
                      onTap: () => ref
                          .read(sleepTimerProvider.notifier)
                          .selectDuration(const Duration(minutes: 60)),
                    ),
                    if (isCustomPreset)
                      _buildPresetChip(
                        context,
                        label: SleepTimerCountdownText.formatDuration(selectedDuration),
                        isSelected: true,
                        onTap: () => CustomSleepTimerSheet.show(
                          context,
                          initialDuration: selectedDuration,
                          onSave: (duration) {
                            ref.read(sleepTimerProvider.notifier).selectDuration(duration);
                          },
                        ),
                      ),
                    _buildPresetChip(
                      context,
                      label: 'Custom...',
                      isSelected: false,
                      onTap: () => CustomSleepTimerSheet.show(
                        context,
                        initialDuration: selectedDuration,
                        onSave: (duration) {
                          ref.read(sleepTimerProvider.notifier).selectDuration(duration);
                        },
                      ),
                    ),
                    _buildPresetChip(
                      context,
                      label: 'End of Track',
                      isSelected: selectedMode == SleepTimerMode.endOfTrack,
                      onTap: () {
                        if (!hasCurrentTrack && isEnabled) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Start playing a track to use End of Track mode.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        ref.read(sleepTimerProvider.notifier).selectEndOfTrack();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Volume Fade Option
                Row(
                  children: [
                    Icon(UIcons.regular.volume, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fade out audio',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Gently scale down volume over the final 10 seconds before stopping',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    ResonanceSwitch(
                      value: fadeOutEnabled,
                      onChanged: (val) => ref.read(sleepTimerProvider.notifier).setFadeOut(val),
                    ),
                  ],
                ),

                // Action controls row
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (isEnabled) ...[
                      if (isDurationMode)
                        ResonanceButton(
                          label: '+5 min',
                          icon: UIcons.regular.plus_small,
                          style: ResonanceButtonStyle.secondary,
                          onPressed: () => ref.read(sleepTimerProvider.notifier).addMinutes(5),
                        ),
                      ResonanceButton(
                        label: 'Deactivate',
                        icon: UIcons.regular.power,
                        style: ResonanceButtonStyle.danger,
                        onPressed: () => ref.read(sleepTimerProvider.notifier).deactivate(),
                      ),
                    ] else ...[
                      ResonanceButton(
                        label: 'Activate (${selectedMode == SleepTimerMode.endOfTrack ? 'End of Track' : SleepTimerCountdownText.formatDuration(selectedDuration)})',
                        icon: UIcons.regular.play,
                        style: ResonanceButtonStyle.primary,
                        onPressed: () {
                          if (selectedMode == SleepTimerMode.endOfTrack && !hasCurrentTrack) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Start playing a track to use End of Track mode.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          ref.read(sleepTimerProvider.notifier).activate();
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected
          ? theme.primaryColor.withValues(alpha: 0.15)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? theme.primaryColor
              : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? theme.primaryColor : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

