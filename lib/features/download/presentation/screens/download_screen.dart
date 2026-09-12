import 'package:resonance/core/widgets/widgets.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/utils/app_icons.dart';

import 'package:resonance/features/download/data/models/download_item.dart';
import 'package:resonance/features/download/application/providers/download_provider.dart';
import 'package:resonance/features/download/application/providers/download_settings_provider.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';
import 'package:resonance/features/download/application/utils/download_input_detector.dart';

class DownloadScreen extends ConsumerStatefulWidget {
  final bool showHeader;
  const DownloadScreen({super.key, this.showHeader = true});

  @override
  ConsumerState<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<DownloadScreen>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  DownloadType _selectedType = DownloadType.audio;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    if (Platform.isAndroid) {
      _selectedType = DownloadType.audio;
    }
  }

  void _onUrlChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _addToQueue() {
    final text = _urlController.text.trim();
    if (text.isEmpty) return;

    final analysis = DownloadInputDetector.analyze(text);
    if (!analysis.isValid) {
      ref.read(notificationProvider.notifier).showNotification(
        'Invalid Input',
        analysis.warningMessage ?? 'Please provide valid YouTube URLs or song titles.',
        isError: true,
        target: 'target:download',
      );
      return;
    }

    final validUrls = analysis.items.where((i) => i.isValid).map((i) => i.raw).toList();
    if (validUrls.isEmpty) return;

    ref.read(downloadProvider.notifier).addToQueue(
      validUrls,
      type: _selectedType,
      source: analysis.resolvedSource,
    );
    _urlController.clear();

    ref.read(notificationProvider.notifier).showNotification(
      'Download Queue',
      'Added ${validUrls.length} item${validUrls.length == 1 ? '' : 's'} to queue',
      target: 'target:download',
      silentOsNotification: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(downloadProvider);
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(downloadSettingsProvider);
    final settings = settingsAsync.value;
    final isDesktop = AppBreakpoints.isWide(context);

    final activeCount =
        queue.where((e) => e.status == DownloadStatus.downloading).length;
    final queuedCount =
        queue.where((e) => e.status == DownloadStatus.queued).length;
    final doneCount =
        queue.where((e) => e.status == DownloadStatus.done).length;

    return Scaffold(
      body: Column(
        children: [
          if (widget.showHeader) ...[
            if (isDesktop) ...[
              TopNavigationHeader(
                left: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        'Downloads',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      '$activeCount active · $queuedCount queued · $doneCount done',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
                right: const SizedBox(),
              ),
            ] else ...[
              TopNavigationHeader(
                left: Text(
                  'Download Manager',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                right: const SizedBox(),
              ),
              Container(
                height: 28,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  '$activeCount active · $queuedCount queued · $doneCount done',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            ],
          ],
          Expanded(
            child: SilkyCustomScrollView(
              slivers: [

          // ─── Input Panel ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _DownloadInputPanel(
              urlController: _urlController,
              selectedType: _selectedType,
              settings: settings,
              onAddToQueue: _addToQueue,
            ),
          ),

          // ─── Queue Header ─────────────────────────────────────────
          if (queue.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Queue',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (doneCount > 0)
                      ResonanceButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dlg) => ResonanceConfirmDialog(
                              title: 'Clear Completed Downloads',
                              content: 'Are you sure you want to clear all finished downloads from the queue history?',
                              confirmLabel: 'Clear',
                              isDanger: true,
                              onConfirm: () async {
                                ref.read(downloadProvider.notifier).clearCompleted();
                              },
                            ),
                          );
                        },
                        icon: UIcons.regular.trash,
                        label: 'Clear done',
                        style: ResonanceButtonStyle.secondary,
                      ),
                  ],
                ),
              ),
            ),

          // ─── Queue List / Empty State ─────────────────────────────
          if (queue.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.download,
                      size: 48,
                      color: theme.disabledColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No downloads yet',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paste a URL or song name above',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DownloadTile(item: queue[i]),
                  ),
                  childCount: queue.length,
                ),
              ),
            ),
        ],
      ),
    ),
  ],
),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Per-item download tile
// ──────────────────────────────────────────────────────────────

class _DownloadTile extends ConsumerStatefulWidget {
  const _DownloadTile({required this.item});
  final DownloadItem item;

  @override
  ConsumerState<_DownloadTile> createState() => _DownloadTileState();
}

class _DownloadTileState extends ConsumerState<_DownloadTile> {
  bool _isExpanded = false;

  Color _statusColor(BuildContext ctx) {
    switch (widget.item.status) {
      case DownloadStatus.done:
        return Colors.green;
      case DownloadStatus.error:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.orange;
      case DownloadStatus.downloading:
        return Theme.of(ctx).colorScheme.primary;
      default:
        return Theme.of(ctx).hintColor;
    }
  }

  String _statusLabel() {
    switch (widget.item.status) {
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.downloading:
        return '${widget.item.progress.toStringAsFixed(0)}%'
            '${widget.item.speed != null ? ' · ${widget.item.speed}' : ''}';
      case DownloadStatus.done:
        return 'Done';
      case DownloadStatus.error:
        return 'Error';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(context);
    final item = widget.item;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Type icon
                      Icon(
                        item.type == DownloadType.audio
                            ? AppIcons.music
                            : AppIcons.video,
                        size: 18,
                        color: theme.hintColor,
                      ),
                      const SizedBox(width: 8),
                      // Title
                      Expanded(
                        child: Text(
                          item.effectiveTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          _statusLabel(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Expand/Collapse icon
                      Icon(
                        _isExpanded ? UIcons.regular.angle_small_up : AppIcons.collapseDown,
                        size: 20,
                        color: theme.hintColor,
                      ),
                      // Cancel button
                      if (item.status == DownloadStatus.queued ||
                          item.status == DownloadStatus.downloading)
                        ReusableHoverIconButton(
                          icon: UIcons.regular.cross,
                          iconSize: 16,
                          tooltip: 'Cancel',
                          onTap: () => ref
                              .read(downloadProvider.notifier)
                              .cancelItem(item.id),
                        ),
                    ],
                  ),
                  // Progress bar
                  if (item.status == DownloadStatus.downloading) ...[
                    const SizedBox(height: 8),
                    if (item.statusMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          item.statusMessage!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                        ),
                      ),
                    LinearProgressIndicator(
                      value: item.progress / 100.0,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                  if (item.status == DownloadStatus.queued)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(value: null),
                    ),
                  // Basic success info if not expanded
                  if (item.status == DownloadStatus.done && !_isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Finished download successfully.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  // Error info if not expanded
                  if (item.status == DownloadStatus.error &&
                      !_isExpanded &&
                      item.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Error occurred. Tap for details.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ─── Expanded Logs Section ──────────────────────────────
          if (_isExpanded)
            _DownloadTileExpandedLogs(
              item: item,
              etaFormatted: item.eta != null ? _formatEta(item.eta!) : null,
            ),
        ],
      ),
    );
  }

  String _formatEta(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }
}

class _DownloadInputPanel extends StatelessWidget {
  const _DownloadInputPanel({
    required this.urlController,
    required this.selectedType,
    required this.settings,
    required this.onAddToQueue,
  });

  final TextEditingController urlController;
  final DownloadType selectedType;
  final dynamic settings;
  final VoidCallback onAddToQueue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analysis = DownloadInputDetector.analyze(urlController.text);
    final hasInput = urlController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // URL input — modern filled style with pinned clear button
              Stack(
                children: [
                  TextField(
                    controller: urlController,
                    maxLines: 4,
                    minLines: 2,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText:
                          'Paste URL(s) or song name…\nOne per line for batch',
                      hintStyle: TextStyle(
                        color: theme.hintColor.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      contentPadding:
                          const EdgeInsets.fromLTRB(14, 12, 44, 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.08),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 8,
                    child: Center(
                      child: ReusableHoverIconButton(
                        icon: UIcons.regular.cross_small,
                        iconSize: 14,
                        padding: 4.0,
                        scaleOnHover: 1.0,
                        borderRadius: BorderRadius.circular(6),
                        tooltip: 'Clear',
                        onTap: () => urlController.clear(),
                      ),
                    ),
                  ),
                ],
              ),

              // ─── Real-Time Detection Pill & Feedback ─────────────────────
              if (hasInput) ...[
                const SizedBox(height: 10),
                if (analysis.hasUnsupportedUrl)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          UIcons.regular.cross_circle,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            analysis.warningMessage ?? 'Unsupported link format.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      _buildDetectedFormatBadge(theme, analysis),
                      const Spacer(),
                      if (analysis.totalCount > 1)
                        Text(
                          '${analysis.validCount} valid / ${analysis.totalCount} total',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  if (analysis.hasPlaylist) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.playlist_play_rounded,
                            size: 18,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              analysis.warningMessage ??
                                  'Playlist link detected. Use Library > Playlists to auto-cache.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.amber.shade300,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],

              // ─── Output path info ───────────────────────────────────────
              if (settings != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 13,
                        color: theme.hintColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          selectedType == DownloadType.audio
                              ? settings.musicOutputPath
                              : settings.videoOutputPath,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Add button
              ResonanceButton(
                onPressed: (hasInput && analysis.isValid) ? onAddToQueue : null,
                icon: AppIcons.add,
                label: 'Add to Queue',
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetectedFormatBadge(ThemeData theme, DownloadInputAnalysis analysis) {
    final IconData icon;
    final String label;
    final Color badgeColor;

    if (analysis.totalCount > 1) {
      icon = Icons.dynamic_feed_rounded;
      label = 'Batch Input (${analysis.validCount} items)';
      badgeColor = theme.colorScheme.primary;
    } else {
      switch (analysis.primaryType) {
        case DownloadInputType.youtubeMusic:
          icon = Icons.music_note_rounded;
          label = 'YouTube Music (Audio)';
          badgeColor = const Color(0xFF00BFA5);
          break;
        case DownloadInputType.youtubeVideo:
          icon = Icons.play_circle_filled_rounded;
          label = 'YouTube (Audio)';
          badgeColor = const Color(0xFFFF5252);
          break;
        case DownloadInputType.youtubePlaylist:
          icon = Icons.playlist_play_rounded;
          label = 'YouTube Playlist';
          badgeColor = Colors.amber;
          break;
        case DownloadInputType.songSearch:
          icon = Icons.search_rounded;
          label = 'Song Search (Top match)';
          badgeColor = theme.colorScheme.primary;
          break;
        default:
          icon = Icons.help_outline_rounded;
          label = 'Auto-detect';
          badgeColor = theme.hintColor;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTileExpandedLogs extends StatelessWidget {
  const _DownloadTileExpandedLogs({
    required this.item,
    required this.etaFormatted,
  });

  final DownloadItem item;
  final String? etaFormatted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LOGS / STATUS',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.brightness == Brightness.light
                      ? Colors.black.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                ),
              ),
              if (etaFormatted != null &&
                  item.status == DownloadStatus.downloading)
                Text(
                  'ETA: $etaFormatted',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Logs container
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant
                    .withValues(alpha: 0.5),
              ),
            ),
            child: item.logs.isEmpty && item.errorMessage == null
                ? Center(
                    child: Text(
                      'No logs yet...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : SilkySingleChildScrollView(
                    reverse: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...item.logs.map(
                          (log) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '> $log',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        if (item.status == DownloadStatus.error &&
                            item.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'ERROR: ${item.errorMessage}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.red.shade300,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                fontSize: 10,
                              ),
                            ),
                          ),
                        if (item.status == DownloadStatus.done &&
                            item.outputPath != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'SUCCESS: File saved to ${item.outputPath}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green.shade300,
                                fontFamily: 'monospace',
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

