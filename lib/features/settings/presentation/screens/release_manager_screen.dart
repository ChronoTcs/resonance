import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/settings/application/update_provider.dart';
import 'package:resonance/features/settings/data/models/release_model.dart';

class ReleaseManagerScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const ReleaseManagerScreen({super.key, this.onBack});

  @override
  ConsumerState<ReleaseManagerScreen> createState() => _ReleaseManagerScreenState();
}

class _ReleaseManagerScreenState extends ConsumerState<ReleaseManagerScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(updateProvider.notifier).fetchReleases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updateState = ref.watch(updateProvider);
    final updateNotifier = ref.read(updateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Page Header with Back Button ─────────────────────────────────
        Row(
          children: [
            ReusableHoverIconButton(
              icon: UIcons.regular.angle_small_left,
              tooltip: 'Back to Settings',
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              iconSize: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Releases & Updates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (updateState.currentVersion.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(UIcons.regular.info, size: 12, color: theme.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'Installed: v${updateState.currentVersion}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // ── 2. Main Content View ─────────────────────────────────────────────
        if (updateState.isChecking)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: theme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Fetching releases from GitHub...',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else if (updateState.error != null && updateState.releases.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(UIcons.regular.cross_circle, size: 36, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    updateState.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  ResonanceButton(
                    icon: UIcons.regular.refresh,
                    label: 'Retry',
                    onPressed: () => updateNotifier.fetchReleases(),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // ── Section 1: Latest Release ──────────────────────────────────────
          if (updateState.latestRelease != null) ...[
            _buildSectionHeader(context, 'Latest Release', UIcons.regular.star),
            const SizedBox(height: 10),
            _buildLatestReleaseCard(
              context,
              release: updateState.latestRelease!,
              updateState: updateState,
              updateNotifier: updateNotifier,
            ),
            const SizedBox(height: 24),
          ],

          // ── Section 2: Older Versions ──────────────────────────────────────
          if (updateState.olderReleases.isNotEmpty) ...[
            _buildSectionHeader(context, 'Older Versions', UIcons.regular.time_past),
            const SizedBox(height: 10),
            Material(
              color: theme.colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < updateState.olderReleases.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _buildOlderReleaseTile(
                      context,
                      release: updateState.olderReleases[i],
                      updateState: updateState,
                      updateNotifier: updateNotifier,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
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

  Widget _buildLatestReleaseCard(
    BuildContext context, {
    required AppRelease release,
    required UpdateState updateState,
    required UpdateNotifier updateNotifier,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: release.isCurrentVersion
              ? theme.primaryColor.withValues(alpha: 0.5)
              : theme.dividerColor.withValues(alpha: 0.08),
          width: release.isCurrentVersion ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  release.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${release.tagName})',
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                if (release.isCurrentVersion) ...[
                  _buildBadge(
                    context,
                    label: 'CURRENT INSTALLED',
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                ],
                if (release.isBeta) ...[
                  _buildBadge(
                    context,
                    label: 'BETA',
                    color: Colors.orangeAccent,
                  ),
                ] else ...[
                  _buildBadge(
                    context,
                    label: 'STABLE',
                    color: Colors.greenAccent,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            FormattedMarkdownText(
              markdown: release.body,
            ),
            const SizedBox(height: 16),

            _buildActionSection(context, release: release, updateState: updateState, updateNotifier: updateNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildOlderReleaseTile(
    BuildContext context, {
    required AppRelease release,
    required UpdateState updateState,
    required UpdateNotifier updateNotifier,
  }) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(
          release.isCurrentVersion ? UIcons.regular.check_circle : UIcons.regular.angle_small_right,
          size: 18,
          color: release.isCurrentVersion ? theme.primaryColor : theme.colorScheme.onSurfaceVariant,
        ),
        title: Row(
          children: [
            Text(
              release.tagName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(width: 8),
            if (release.isCurrentVersion) ...[
              _buildBadge(
                context,
                label: 'CURRENT',
                color: theme.primaryColor,
              ),
              const SizedBox(width: 6),
            ],
            if (release.isBeta) ...[
              _buildBadge(
                context,
                label: 'BETA',
                color: Colors.orangeAccent,
              ),
            ],
          ],
        ),
        subtitle: Text(
          release.name,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormattedMarkdownText(
            markdown: release.body,
          ),
          const SizedBox(height: 12),
          _buildActionSection(context, release: release, updateState: updateState, updateNotifier: updateNotifier),
        ],
      ),
    );
  }

  Widget _buildActionSection(
    BuildContext context, {
    required AppRelease release,
    required UpdateState updateState,
    required UpdateNotifier updateNotifier,
  }) {
    final theme = Theme.of(context);
    final isSelected = updateState.selectedRelease?.tagName == release.tagName;

    // Current version: only show badge container, no download action
    if (release.isCurrentVersion) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(UIcons.regular.check, size: 14, color: theme.primaryColor),
            const SizedBox(width: 6),
            Text(
              'You are running this version',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.primaryColor),
            ),
          ],
        ),
      );
    }

    // Show in-progress download bar with cancel button
    if (isSelected && updateState.isDownloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: updateState.downloadProgress,
                  color: theme.primaryColor,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => updateNotifier.cancelDownload(),
                borderRadius: BorderRadius.circular(12),
                child: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Downloading ${release.tagName}: ${(updateState.downloadProgress * 100).toInt()}%',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    // Show in-progress patching/staging
    if (isSelected && updateState.isPatching) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            color: theme.primaryColor,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 6),
          Text(
            'Staging delta update for ${release.tagName}...',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    // Show Restart & Apply if update is staged, or Install if full installer downloaded
    if (isSelected && (updateState.isUpdateReadyToRestart || updateState.downloadProgress >= 1.0)) {
      final isStaged = updateState.isUpdateReadyToRestart;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ResonanceButton(
            icon: isStaged ? UIcons.regular.refresh : UIcons.regular.download,
            label: isStaged
                ? 'Restart & Apply Update (${release.tagName})'
                : 'Install Version ${release.tagName}',
            style: ResonanceButtonStyle.primary,
            onPressed: () => isStaged
                ? updateNotifier.applyAndRestart()
                : updateNotifier.installRelease(context, release),
          ),
          const SizedBox(width: 8),
          ResonanceButton(
            icon: UIcons.regular.trash,
            label: isStaged ? 'Discard' : 'Delete',
            style: ResonanceButtonStyle.danger,
            onPressed: () => _confirmDeleteInstaller(context, release, updateNotifier),
          ),
        ],
      );
    }

    // Download button — shown for upgrade (newer) or downgrade (older)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (release.isOlderThanCurrent)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Older than installed version — downgrade at your own risk',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ResonanceButton(
          icon: UIcons.regular.download,
          label: 'Download & Install ${release.tagName}',
          style: release.isNewerThanCurrent
              ? ResonanceButtonStyle.primary
              : ResonanceButtonStyle.secondary,
          onPressed: () => updateNotifier.downloadRelease(release),
        ),
      ],
    );
  }

  void _confirmDeleteInstaller(
    BuildContext context,
    AppRelease release,
    UpdateNotifier updateNotifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => ResonanceConfirmDialog(
        title: 'Delete Installer for ${release.tagName}?',
        content: 'Are you sure you want to delete the downloaded installer file from your device? You can download it again anytime.',
        confirmLabel: 'Delete',
        isDanger: true,
        onConfirm: () {
          updateNotifier.deleteDownloadedRelease(release);
        },
      ),
    );
  }

  Widget _buildBadge(BuildContext context, {required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Renders raw release notes Markdown with uniform collapsed height (140px)
/// and interactive expand/collapse toggle for long notes.
class FormattedMarkdownText extends StatefulWidget {
  final String markdown;
  final double collapsedHeight;
  final double expandedHeight;

  const FormattedMarkdownText({
    super.key,
    required this.markdown,
    this.collapsedHeight = 140.0,
    this.expandedHeight = 450.0,
  });

  @override
  State<FormattedMarkdownText> createState() => _FormattedMarkdownTextState();
}

class _FormattedMarkdownTextState extends State<FormattedMarkdownText> {
  bool _isExpanded = false;
  bool _isHovered = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final lines = widget.markdown.split('\n');
    final List<Widget> widgets = [];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();

      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Divider / HR
      if (line.trim() == '---' || line.trim() == '***') {
        widgets.add(Divider(color: colorScheme.outline.withValues(alpha: 0.2), height: 16));
        continue;
      }

      // Blockquote
      if (line.trim().startsWith('>')) {
        final quoteText = line.trim().substring(1).trim();
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border(
                left: BorderSide(color: colorScheme.primary, width: 3),
              ),
            ),
            child: _buildRichText(context, quoteText, style: TextStyle(fontSize: 13, color: colorScheme.onSurface)),
          ),
        );
        continue;
      }

      // Headings
      if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              line.substring(2).trim(),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              line.substring(3).trim(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              line.substring(4).trim(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        );
        continue;
      }

      // Bullet items
      if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
        final bulletContent = line.trim().substring(2).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildRichText(
                    context,
                    bulletContent,
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Regular Paragraph line
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildRichText(
            context,
            line,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ),
      );
    }

    final double currentMaxHeight = _isExpanded ? widget.expandedHeight : widget.collapsedHeight;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: currentMaxHeight),
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered
                  ? colorScheme.primary.withValues(alpha: 0.4)
                  : colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: _isExpanded ? const BouncingScrollPhysics() : const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: widgets,
                      ),
                    ),
                  ),
                ),
              ),
              // Expand / Collapse Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isExpanded ? 'Show Less' : 'Show More',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded ? UIcons.regular.angle_small_up : UIcons.regular.angle_small_down,
                      size: 14,
                      color: _isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichText(BuildContext context, String text, {required TextStyle style}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final List<InlineSpan> spans = [];

    final regex = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)');
    int start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: style));
      }
      final matchText = match.group(0)!;
      if (matchText.startsWith('**') && matchText.endsWith('**')) {
        spans.add(
          TextSpan(
            text: matchText.substring(2, matchText.length - 2),
            style: style.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        );
      } else if (matchText.startsWith('*') && matchText.endsWith('*')) {
        spans.add(
          TextSpan(
            text: matchText.substring(1, matchText.length - 1),
            style: style.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (matchText.startsWith('`') && matchText.endsWith('`')) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                matchText.substring(1, matchText.length - 1),
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      }
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
