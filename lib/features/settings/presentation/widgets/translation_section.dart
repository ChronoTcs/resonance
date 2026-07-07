import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/core/utils/uicons.dart';
import '../../../lyrics/application/lyrics_translation_provider.dart';
import 'settings_widgets.dart';

class TranslationSection extends ConsumerWidget {
  const TranslationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationState = ref.watch(lyricsTranslationProvider);
    final translationNotifier = ref.read(lyricsTranslationProvider.notifier);
    final theme = Theme.of(context);

    final Map<String, String> languages = {
      'id': 'Indonesian',
      'en': 'English',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh-cn': 'Chinese (Simplified)',
      'zh-tw': 'Chinese (Traditional)',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'ru': 'Russian',
      'ar': 'Arabic',
      'pt': 'Portuguese',
      'it': 'Italian',
      'vi': 'Vietnamese',
      'th': 'Thai',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lyrics Translation',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        
        ListTile(
          leading: Icon(UIcons.regular.language),
          title: const Text('Show Translation Button'),
          subtitle: const Text('Show a button to translate lyrics in the player'),
          trailing: Switch(
            value: translationState.isSystemEnabled,
            onChanged: (val) => translationNotifier.toggleSystemEnabled(),
            activeThumbColor: theme.primaryColor,
          ),
          tileColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        
        const SizedBox(height: 12),
        
        SettingsItemTile(
          icon: UIcons.regular.language,
          title: 'Target Language',
          subtitle: 'Select language to translate to',
          trailing: DropdownButton<String>(
            value: translationState.targetLanguage,
            dropdownColor: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            underline: const SizedBox(),
            items: languages.entries.map((e) {
              return DropdownMenuItem(value: e.key, child: Text(e.value));
            }).toList(),
            onChanged: (lang) {
              if (lang != null) translationNotifier.setTargetLanguage(lang);
            },
          ),
        ),
      ],
    );
  }
}
