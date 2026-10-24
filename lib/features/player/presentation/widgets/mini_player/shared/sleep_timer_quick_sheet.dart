import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/resonance_button.dart';
import 'package:resonance/core/widgets/overlays/floating_sheet_shell.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/providers/sleep_timer_provider.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';
import 'package:resonance/features/settings/presentation/widgets/preferences/custom_sleep_timer_sheet.dart';
import 'package:resonance/features/settings/presentation/widgets/preferences/sleep_timer_countdown_text.dart';

/// Lightweight quick modal bottom sheet allowing single-tap activation
/// and management of the Sleep Timer from player menus and media actions.
class SleepTimerQuickSheet extends ConsumerWidget {
  const SleepTimerQuickSheet({super.key});

  /// Displays the quick sleep timer bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => const SleepTimerQuickSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isEnabled = ref.watch(sleepTimerProvider.select((s) => s.isEnabled));
    final selectedMode = ref.watch(sleepTimerProvider.select((s) => s.selectedMode));
    final selectedDuration = ref.watch(sleepTimerProvider.select((s) => s.selectedDuration));

    final dividerColor = theme.colorScheme.outline.withValues(alpha: isDark ? 0.08 : 0.05);

    return FloatingSheetShell(
      maxWidth: 440,
      title: 'Sleep Timer',
      icon: isEnabled ? UIcons.solid.moon : UIcons.regular.moon,
      onClose: () => Navigator.pop(context),
      children: [
        if (isEnabled) ...[
          _ActiveTimerBanner(selectedMode: selectedMode),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.06),
            ),
          ),
          child: Column(
            children: [
              _PresetRow(
                title: '15 Minutes',
                icon: UIcons.regular.clock,
                isSelected: isEnabled &&
                    selectedMode == SleepTimerMode.duration &&
                    selectedDuration == const Duration(minutes: 15),
                onTap: () => _activateDuration(context, ref, const Duration(minutes: 15)),
              ),
              Divider(height: 1, color: dividerColor),
              _PresetRow(
                title: '30 Minutes',
                icon: UIcons.regular.clock,
                isSelected: isEnabled &&
                    selectedMode == SleepTimerMode.duration &&
                    selectedDuration == const Duration(minutes: 30),
                onTap: () => _activateDuration(context, ref, const Duration(minutes: 30)),
              ),
              Divider(height: 1, color: dividerColor),
              _PresetRow(
                title: '45 Minutes',
                icon: UIcons.regular.clock,
                isSelected: isEnabled &&
                    selectedMode == SleepTimerMode.duration &&
                    selectedDuration == const Duration(minutes: 45),
                onTap: () => _activateDuration(context, ref, const Duration(minutes: 45)),
              ),
              Divider(height: 1, color: dividerColor),
              _PresetRow(
                title: '60 Minutes (1 Hour)',
                icon: UIcons.regular.clock,
                isSelected: isEnabled &&
                    selectedMode == SleepTimerMode.duration &&
                    selectedDuration == const Duration(minutes: 60),
                onTap: () => _activateDuration(context, ref, const Duration(minutes: 60)),
              ),
              Divider(height: 1, color: dividerColor),
              _PresetRow(
                title: 'End of Current Track',
                icon: UIcons.regular.play,
                isSelected: isEnabled && selectedMode == SleepTimerMode.endOfTrack,
                onTap: () => _activateEndOfTrack(context, ref),
              ),
              Divider(height: 1, color: dividerColor),
              _PresetRow(
                title: 'Custom Time...',
                icon: UIcons.regular.settings_sliders,
                isSelected: isEnabled &&
                    selectedMode == SleepTimerMode.duration &&
                    ![15, 30, 45, 60].contains(selectedDuration.inMinutes),
                onTap: () => _openCustomSheet(context, ref, selectedDuration),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _activateDuration(BuildContext context, WidgetRef ref, Duration duration) {
    ref.read(sleepTimerProvider.notifier).setDuration(duration);
    ref.read(notificationProvider.notifier).showNotification(
      'Sleep Timer',
      'Timer set for ${duration.inMinutes} minutes.',
      silentOsNotification: true,
    );
    Navigator.pop(context);
  }

  void _activateEndOfTrack(BuildContext context, WidgetRef ref) {
    final hasCurrentTrack = ref.read(audioProvider).currentTrack != null;
    if (!hasCurrentTrack) {
      ref.read(notificationProvider.notifier).showNotification(
        'Sleep Timer',
        'Start playing a track to use End of Track mode.',
        isError: true,
        silentOsNotification: true,
      );
      return;
    }

    ref.read(sleepTimerProvider.notifier).setEndOfTrack();
    ref.read(notificationProvider.notifier).showNotification(
      'Sleep Timer',
      'Playback will pause after current track finishes.',
      silentOsNotification: true,
    );
    Navigator.pop(context);
  }

  void _openCustomSheet(BuildContext context, WidgetRef ref, Duration currentDuration) {
    final timerNotifier = ref.read(sleepTimerProvider.notifier);
    final notifNotifier = ref.read(notificationProvider.notifier);

    Navigator.pop(context);
    CustomSleepTimerSheet.show(
      context,
      initialDuration: currentDuration,
      onSave: (duration) {
        timerNotifier.setDuration(duration);
        notifNotifier.showNotification(
          'Sleep Timer',
          'Timer set for ${SleepTimerCountdownText.formatDuration(duration)}.',
          silentOsNotification: true,
        );
      },
    );
  }
}

class _ActiveTimerBanner extends ConsumerWidget {
  final SleepTimerMode selectedMode;

  const _ActiveTimerBanner({required this.selectedMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isEndOfTrack = selectedMode == SleepTimerMode.endOfTrack;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(UIcons.solid.moon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: isEndOfTrack
                    ? Text(
                        'Pausing after current track',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Active: ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          SleepTimerCountdownText(
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            ' remaining',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isEndOfTrack) ...[
                ResonanceButton(
                  label: '+5 Min',
                  icon: UIcons.regular.plus,
                  style: ResonanceButtonStyle.secondary,
                  onPressed: () {
                    ref.read(sleepTimerProvider.notifier).addMinutes(5);
                    ref.read(notificationProvider.notifier).showNotification(
                      'Sleep Timer',
                      'Added 5 minutes to sleep timer.',
                      silentOsNotification: true,
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
              ResonanceButton(
                label: 'Turn Off',
                icon: UIcons.regular.cross_small,
                style: ResonanceButtonStyle.danger,
                onPressed: () {
                  ref.read(sleepTimerProvider.notifier).deactivate();
                  ref.read(notificationProvider.notifier).showNotification(
                    'Sleep Timer',
                    'Sleep timer turned off.',
                    silentOsNotification: true,
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetRow extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetRow({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PresetRow> createState() => _PresetRowState();
}

class _PresetRowState extends State<_PresetRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isSelected ? primary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w500,
                    color: widget.isSelected ? primary : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (widget.isSelected)
                Icon(
                  UIcons.regular.check,
                  size: 16,
                  color: primary,
                )
              else
                Icon(
                  UIcons.regular.angle_small_right,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: _isHovered ? 0.9 : 0.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

