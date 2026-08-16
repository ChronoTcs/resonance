import 'package:resonance/core/widgets/widgets.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/utils/app_icons.dart';

import 'package:resonance/features/download/data/models/download_item.dart';
import 'package:resonance/features/download/application/providers/download_provider.dart';
import 'package:resonance/features/download/application/providers/download_settings_provider.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';

class DownloadScreen extends ConsumerStatefulWidget {
  const DownloadScreen({super.key});

  @override
  ConsumerState<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<DownloadScreen>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  DownloadType _selectedType = DownloadType.audio;
  DownloadSource _selectedSource = DownloadSource.ytmusic;

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

    // Split by newline to support multiple URLs at once
    final urls = text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    ref
        .read(downloadProvider.notifier)
        .addToQueue(urls, type: _selectedType, source: _selectedSource);
    _urlController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${urls.length} item${urls.length == 1 ? '' : 's'} to queue',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(downloadProvider);
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(downloadSettingsProvider);
    final settings = settingsAsync.value;

    final activeCount = queue
        .where((i) => i.status == DownloadStatus.downloading)
        .length;
    final queuedCount = queue
        .where((i) => i.status == DownloadStatus.queued)
        .length;
    final doneCount = queue
        .where((i) => i.status == DownloadStatus.done)
        .length;

    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Column(
        children: [
          if (isDesktop) ...[
            TopNavigationHeader(
              left: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Download Manager',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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
          Expanded(
            child: SilkyCustomScrollView(
              slivers: [

          // ─── Android Notice Banner ─────────────────────────────────
          if (Platform.isAndroid)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Direct URL downloads require the desktop Python bridge (unavailable on Android). '
                          'Use the Explore tab to stream or save tracks instead.',
                          style: TextStyle(fontSize: 12, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ─── Input Panel ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
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
                            controller: _urlController,
                            maxLines: 4,
                            minLines: 2,
                            style: theme.textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: 'Paste URL(s) or song name…\nOne per line for batch',
                              hintStyle: TextStyle(
                                color: theme.hintColor.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              contentPadding: const EdgeInsets.fromLTRB(14, 12, 44, 12),
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
                                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
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
                                onTap: () => _urlController.clear(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Source selector
                      ResonanceSelector<DownloadSource>(
                        icon: AppIcons.download,
                        title: 'Source',
                        subtitle: 'Where to fetch from',
                        value: _selectedSource,
                        onChanged: (v) => setState(() => _selectedSource = v),
                        items: const [
                          ResonanceSelectorItem(
                            value: DownloadSource.ytmusic,
                            label: 'YouTube Music',
                          ),
                          ResonanceSelectorItem(
                            value: DownloadSource.youtube,
                            label: 'YouTube',
                          ),
                          ResonanceSelectorItem(
                            value: DownloadSource.auto,
                            label: 'Auto-detect',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Output path info
                      if (settings != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined, size: 13, color: theme.hintColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _selectedType == DownloadType.audio
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
                        onPressed: _addToQueue,
                        icon: AppIcons.add,
                        label: 'Add to Queue',
                        isFullWidth: true,
                      ),
                    ],
                  ),
                ),
              ),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.black.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (item.eta != null &&
                          item.status == DownloadStatus.downloading)
                        Text(
                          'ETA: ${_formatEta(item.eta!)}',
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
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
                            reverse: true, // Always show newest logs
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...item.logs.map(
                                  (log) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      '> $log',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontFamily: 'monospace',
                                            fontSize: 10,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
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
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
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
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
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
