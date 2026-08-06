import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';

import '../../../lyrics/application/lyrics_translation_provider.dart';

class TranslationSection extends ConsumerWidget {
  const TranslationSection({super.key});

  static const Map<String, String> _languages = {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationState = ref.watch(lyricsTranslationProvider);
    final translationNotifier = ref.read(lyricsTranslationProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lyrics Translation',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        // Grouped Lyrics Translation Card Container
        Material(
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(UIcons.regular.language, size: 18, color: theme.primaryColor),
                title: const Text('Show Translation Button', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Show a button to translate lyrics in the player',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
                trailing: ResonanceSwitch(
                  value: translationState.isSystemEnabled,
                  onChanged: (_) => translationNotifier.toggleSystemEnabled(),
                ),
              ),
              const Divider(height: 1),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(UIcons.regular.globe, size: 18, color: theme.primaryColor),
                  title: const Text('Target Language', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'Language to translate lyrics into (${_languages[translationState.targetLanguage] ?? translationState.targetLanguage})',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  children: [
                    for (final entry in _languages.entries)
                      ListTile(
                        dense: true,
                        title: Text(entry.value, style: const TextStyle(fontSize: 13)),
                        trailing: translationState.targetLanguage == entry.key
                            ? Icon(UIcons.regular.check, size: 16, color: theme.primaryColor)
                            : null,
                        onTap: () => translationNotifier.setTargetLanguage(entry.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
