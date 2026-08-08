import 'dart:io';
import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';

class HelpScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const HelpScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Back Button
        Row(
          children: [
            ReusableHoverIconButton(
              icon: UIcons.regular.angle_small_left,
              tooltip: 'Back to Settings',
              onTap: () {
                if (onBack != null) {
                  onBack!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              iconSize: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Help & FAQ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // FAQ Content
        _buildSectionHeader(context, 'Frequently Asked Questions', UIcons.regular.question),
        _buildGroupedCard(context, [
          _buildFAQ(
            context,
            icon: UIcons.regular.music,
            question: 'Where does the music come from?',
            answer: 'Resonance streams music directly from online sources with high-quality audio, synchronized lyrics, and rich album artwork. Explore curated feeds or use global search (Ctrl + F) to find any song, artist, or playlist.',
          ),
          const Divider(height: 1),
          _buildFAQ(
            context,
            icon: UIcons.regular.navigation,
            question: 'How to scroll horizontally across music feeds?',
            answer: '• Laptop Touchpad: Swipe horizontally using two fingers (left/right).\n• Mouse Wheel: Hold the Shift key while scrolling the mouse wheel up or down (Shift + Scroll Wheel).',
          ),
          const Divider(height: 1),
          _buildFAQ(
            context,
            icon: UIcons.regular.cloud_download,
            question: 'Can I listen to music offline?',
            answer: 'Yes! Played and downloaded tracks are cached on your device, allowing seamless offline playback without re-downloading.',
          ),
          const Divider(height: 1),
          _buildFAQ(
            context,
            icon: UIcons.regular.folder,
            question: 'Can I import my own local audio files?',
            answer: 'Direct local folder importing (MP3/FLAC/WAV disk indexing) is planned for a future update. Resonance currently focuses on high-fidelity online streaming and local-powered playlists.',
          ),
        ]),

        if (Platform.isWindows) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Windows Keyboard Shortcuts', UIcons.regular.laptop),
          _buildGroupedCard(context, [
            _buildFAQ(
              context,
              icon: UIcons.regular.play_pause,
              question: 'Playback Controls',
              answer: '• Space: Play / Pause\n• Ctrl + Right: Next Track\n• Ctrl + Left: Previous Track\n• Ctrl + Up / Down: Volume Adjustment',
            ),
            const Divider(height: 1),
            _buildFAQ(
              context,
              icon: UIcons.regular.navigation,
              question: 'Navigation Shortcuts',
              answer: '• Ctrl + F: Global Search\n• Ctrl + L: Open Library\n• Esc: Close Overlay / Current View',
            ),
          ]),
        ],

        const SizedBox(height: 24),
        _buildSectionHeader(context, 'Troubleshooting & Support', UIcons.regular.interrogation),
        _buildGroupedCard(context, [
          _buildFAQ(
            context,
            icon: UIcons.regular.refresh,
            question: 'App is lagging or playback stutters?',
            answer: 'Try clearing cache in Settings > Storage > Cache Management. If the issue persists, report a bug via the "Support Me" menu.',
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.primaryColor),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCard(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildFAQ(
    BuildContext context, {
    required IconData icon,
    required String question,
    required String answer,
  }) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, size: 18, color: theme.primaryColor),
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(52, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
