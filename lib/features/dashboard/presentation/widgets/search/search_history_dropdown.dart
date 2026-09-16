import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/providers/search_history_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';

/// Overlay panel displaying recent search history in a unified card below the search bar.
class SearchHistoryDropdown extends ConsumerWidget {
  const SearchHistoryDropdown({
    super.key,
    required this.link,
    required this.searchWidth,
    required this.groupId,
    required this.onSelect,
    required this.onClose,
  });

  final LayerLink link;
  final double searchWidth;
  final String groupId;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final Color panelBg = theme.colorScheme.surfaceContainerHigh;
    final BorderSide borderSide = BorderSide(
      color: theme.dividerColor.withValues(alpha: 0.2),
      width: 1,
    );

    return TapRegion(
      groupId: groupId,
      child: Align(
        alignment: Alignment.topLeft,
        child: CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false, // Never render at (0, 0) if leader detaches
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, -1), // Flush seamless 1px overlap with search input
          child: Material(
            elevation: 12,
            color: panelBg,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: searchWidth,
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                border: Border(
                  left: borderSide,
                  right: borderSide,
                  bottom: borderSide,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      physics: const BouncingScrollPhysics(),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        return SearchHistoryItemRow(
                          query: item,
                          onSelect: () => onSelect(item),
                          onDelete: () {
                            ref
                                .read(searchHistoryProvider.notifier)
                                .removeQuery(item);
                            if (history.length <= 1) {
                              onClose();
                            }
                          },
                        );
                      },
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                  InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () {
                      ref.read(searchHistoryProvider.notifier).clearAll();
                      onClose();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            UIcons.regular.trash,
                            size: 12,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Clear Search History',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single row item in the search history dropdown with clock icon, query text, and delete action.
class SearchHistoryItemRow extends StatefulWidget {
  final String query;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const SearchHistoryItemRow({
    super.key,
    required this.query,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  State<SearchHistoryItemRow> createState() => _SearchHistoryItemRowState();
}

class _SearchHistoryItemRowState extends State<SearchHistoryItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: widget.onSelect,
        child: Container(
          color: _isHovered
              ? theme.colorScheme.onSurface.withValues(alpha: 0.06)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Icon(
                UIcons.regular.time_past,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ReusableHoverIconButton(
                icon: UIcons.regular.trash,
                iconSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                tooltip: 'Remove',
                padding: 4,
                onTap: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
