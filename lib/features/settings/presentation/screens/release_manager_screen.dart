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

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                release.body,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              release.body,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, height: 1.4),
            ),
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

    if (isSelected && updateState.isDownloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: updateState.downloadProgress,
            color: theme.primaryColor,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 6),
          Text(
            'Downloading update: ${(updateState.downloadProgress * 100).toInt()}%',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    if (isSelected && updateState.downloadProgress >= 1.0) {
      return ResonanceButton(
        icon: UIcons.regular.download,
        label: 'Install Version ${release.tagName}',
        style: ResonanceButtonStyle.primary,
        onPressed: () => updateNotifier.installRelease(context, release),
      );
    }

    return ResonanceButton(
      icon: UIcons.regular.download,
      label: 'Download & Install ${release.tagName}',
      style: ResonanceButtonStyle.secondary,
      onPressed: () => updateNotifier.downloadRelease(release),
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
