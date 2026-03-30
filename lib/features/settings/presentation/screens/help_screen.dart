import 'dart:io';
import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Frequently Asked Questions'),
          _buildFAQ(
            context,
            'How to add music?',
            'Go to Settings > Library Paths and select your music folder. Resonance will automatically scan and index your tracks.',
          ),
          _buildFAQ(
            context,
            'Does it support FLAC/WAV?',
            'Yes, Resonance supports all major audio formats including MP3, FLAC, WAV, OGG, and AAC.',
          ),
          
          if (Platform.isWindows) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Windows Keyboard Shortcuts'),
            _buildFAQ(
              context,
              'Playback Controls',
              '• Space: Play/Pause\n• Ctrl + Right: Next Track\n• Ctrl + Left: Previous Track\n• Ctrl + Up/Down: Volume +/-',
            ),
            _buildFAQ(
              context,
              'Navigation',
              '• Ctrl + F: Global Search\n• Ctrl + L: Toggle Library\n• Esc: Close Current View',
            ),
          ],
          
          if (!Platform.isAndroid) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Video Tab Guide'),
            _buildFAQ(
              context,
              'Watching Videos',
              'The Video tab allows you to play local MKV/MP4 files with hardware acceleration support.',
            ),
          ],
          
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Troubleshooting'),
          _buildFAQ(
            context,
            'App is lagging or crashing?',
            'Try clearing the cache from Settings > Cache Management. If the issue persists, please report it via "Support Me" menu.',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFAQ(BuildContext context, String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        iconColor: Theme.of(context).primaryColor,
        textColor: Theme.of(context).primaryColor,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
