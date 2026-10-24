import 'package:flutter/material.dart';

import 'preferences/app_behavior_card.dart';
import 'preferences/preferences_updates_card.dart';
import 'preferences/sleep_timer_card.dart';
import 'preferences/sleep_timer_countdown_text.dart';

export 'preferences/app_behavior_card.dart';
export 'preferences/custom_sleep_timer_sheet.dart';
export 'preferences/preferences_updates_card.dart';
export 'preferences/sleep_timer_card.dart';
export 'preferences/sleep_timer_countdown_text.dart';

/// Clean, modular coordinator for the Preferences section in Settings.
/// Decomposes Sleep Timer, App Behavior, and Updates into isolated, single-responsibility cards.
class PreferencesSection extends StatelessWidget {
  const PreferencesSection({super.key});

  /// Canonical duration formatter maintained for backward-compatibility.
  static String formatDuration(Duration d) => SleepTimerCountdownText.formatDuration(d);

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SleepTimerCard(),
        SizedBox(height: 24),
        AppBehaviorCard(),
        SizedBox(height: 24),
        PreferencesUpdatesCard(),
      ],
    );
  }
}
