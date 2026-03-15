import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/download/data/models/download_item.dart';
import 'package:resonance_app/features/download/data/repositories/download_provider.dart';
import 'package:resonance_app/features/download/data/repositories/download_settings_provider.dart';
import 'package:resonance_app/features/download/presentation/screens/download_settings_screen.dart';

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
  void dispose() {
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

    return Scaffold(
      body: Column(
        children: [
          // ─── Header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Download Manager',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$activeCount active · $queuedCount queued · $doneCount done',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DownloadSettingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Download Settings',
                ),
              ],
            ),
          ),

          // ─── Input Panel ──────────────────────────────────────────
          Padding(
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
                    // URL input
                    TextField(
                      controller: _urlController,
                      maxLines: 4,
                      minLines: 2,
                      decoration: InputDecoration(
                        hintText:
                            'Paste URL(s) or type a song name…\n(One per line for batch download)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _urlController.clear(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Type + Source selectors
                    Row(
                      children: [
                        // Type
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Type',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SegmentedButton<DownloadType>(
                                segments: const [
                                  ButtonSegment(
                                    value: DownloadType.audio,
                                    label: Text('Audio'),
                                    icon: Icon(Icons.music_note, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: DownloadType.video,
                                    label: Text('Video'),
                                    icon: Icon(Icons.movie_outlined, size: 16),
                                  ),
                                ],
                                selected: {_selectedType},
                                onSelectionChanged: (s) =>
                                    setState(() => _selectedType = s.first),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Source
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Source',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<DownloadSource>(
                                value: _selectedSource,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: DownloadSource.ytmusic,
                                    child: Text('YouTube Music'),
                                  ),
                                  DropdownMenuItem(
                                    value: DownloadSource.youtube,
                                    child: Text('YouTube'),
                                  ),
                                  DropdownMenuItem(
                                    value: DownloadSource.auto,
                                    child: Text('Auto-detect'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedSource = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Output path info
                    if (settings != null)
                      Text(
                        _selectedType == DownloadType.audio
                            ? '📁 ${settings.musicOutputPath}'
                            : '📁 ${settings.videoOutputPath}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 12),

                    // Add button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _addToQueue,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add to Queue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Queue Header ─────────────────────────────────────────
          if (queue.isNotEmpty) ...[
            Padding(
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
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(downloadProvider.notifier).clearCompleted(),
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear done'),
                    ),
                ],
              ),
            ),
          ],

          // ─── Queue List ───────────────────────────────────────────
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download_outlined,
                          size: 72,
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
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: queue.length,
                    itemBuilder: (ctx, i) => _DownloadTile(item: queue[i]),
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
                            ? Icons.music_note
                            : Icons.movie_outlined,
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
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
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
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: theme.hintColor,
                      ),
                      // Cancel button
                      if (item.status == DownloadStatus.queued ||
                          item.status == DownloadStatus.downloading)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 16),
                          padding: EdgeInsets.zero,
                          onPressed: () => ref
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
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
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
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.5,
                ),
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
                          color: theme.hintColor,
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
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
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
                        : SingleChildScrollView(
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
