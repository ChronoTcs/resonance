import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/overlays/floating_sheet_shell.dart';
import 'package:resonance/features/player/application/services/equalizer_service.dart';

/// Horizontal 1-tap chip carousel and full categorized preset picker modal.
class EqualizerPresetSelector extends StatelessWidget {
  final String activePreset;
  final ValueChanged<String> onPresetSelected;

  const EqualizerPresetSelector({
    super.key,
    required this.activePreset,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Display popular presets, plus the active preset if it's not in the popular list
    final chips = <String>[...kPopularEqualizerPresets];
    if (!chips.contains(activePreset) && activePreset.isNotEmpty) {
      chips.insert(1, activePreset);
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: chips.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All Presets" button
            return _AllPresetsButton(
              activePreset: activePreset,
              onTap: () => _showAllPresetsSheet(context),
            );
          }

          final presetName = chips[index - 1];
          final isSelected = presetName == activePreset;

          return _PresetChip(
            label: presetName,
            isSelected: isSelected,
            isDark: isDark,
            colorScheme: colorScheme,
            onTap: () {
              if (!isSelected && presetName != 'Custom') {
                onPresetSelected(presetName);
              }
            },
          );
        },
      ),
    );
  }

  void _showAllPresetsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _EqualizerPresetsModal(
        activePreset: activePreset,
        onPresetSelected: (preset) {
          onPresetSelected(preset);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest.withValues(
                    alpha: isDark ? 0.35 : 0.55,
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  UIcons.regular.check,
                  size: 13,
                  color: colorScheme.onPrimary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllPresetsButton extends StatelessWidget {
  final String activePreset;
  final VoidCallback onTap;

  const _AllPresetsButton({
    required this.activePreset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.45 : 0.65,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.35),
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                UIcons.regular.apps,
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'All (${kEqualizerPresets.length - 2})', // Exclude Custom and backwards-compat alias
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Categorized full preset picker modal
class _EqualizerPresetsModal extends StatefulWidget {
  final String activePreset;
  final ValueChanged<String> onPresetSelected;

  const _EqualizerPresetsModal({
    required this.activePreset,
    required this.onPresetSelected,
  });

  @override
  State<_EqualizerPresetsModal> createState() => _EqualizerPresetsModalState();
}

class _EqualizerPresetsModalState extends State<_EqualizerPresetsModal> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Filter categories based on search
    final filteredCategories = <String, List<String>>{};
    final query = _searchQuery.trim().toLowerCase();

    for (final entry in kEqualizerPresetCategories.entries) {
      final category = entry.key;
      final presets = entry.value.where((p) {
        if (p == 'Custom') return false; // Handled separately
        if (query.isEmpty) return true;
        return p.toLowerCase().contains(query) ||
            category.toLowerCase().contains(query);
      }).toList();

      if (presets.isNotEmpty) {
        filteredCategories[category] = presets;
      }
    }

    return FloatingSheetShell(
      maxWidth: 520,
      title: 'Equalizer Presets',
      icon: UIcons.regular.settings_sliders,
      children: [
        // Search Input
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.35 : 0.5,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                UIcons.regular.search,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search presets (e.g. Bass, Rock, Jazz)...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(
                    UIcons.regular.cross_small,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Category Groups
        if (filteredCategories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No presets matching "$_searchQuery"',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...filteredCategories.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: isDark ? 0.25 : 0.35,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outline.withValues(
                        alpha: isDark ? 0.08 : 0.05,
                      ),
                    ),
                  ),
                  child: Column(
                    children: entry.value.map((presetName) {
                      final isSelected = widget.activePreset == presetName;
                      final isLast = entry.value.last == presetName;

                      return InkWell(
                        onTap: () => widget.onPresetSelected(presetName),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : Border(
                                    bottom: BorderSide(
                                      color: colorScheme.outline.withValues(
                                        alpha: isDark ? 0.08 : 0.04,
                                      ),
                                    ),
                                  ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                presetName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  UIcons.regular.check,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          }),
        const SizedBox(height: 8),
      ],
    );
  }
}
