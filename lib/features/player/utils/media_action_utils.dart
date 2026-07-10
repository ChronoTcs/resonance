import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/core/widgets/media_actions_bottom_sheet.dart';


class MediaActionUtils {
  static void showMediaActions({
    required BuildContext context,
    required WidgetRef ref,
    required MediaItem item,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => MediaActionsBottomSheet(
        item: item,
        onDelete: item.id == null ? () => confirmDelete(context, ref, item) : null,
      ),
    );
  }

  static void confirmDelete(BuildContext context, WidgetRef ref, MediaItem item) {
    showDialog(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Delete Track'),
        content: Text('Permanently delete "${item.title}" from your device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlg), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(dlg);
              // ref.read(audioProvider.notifier).deleteCurrentTrack(); // TODO: Recheck the correct delete method
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
