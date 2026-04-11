import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../data/models/download_item.dart';
import '../download_service.dart';

/// Public provider for the Download Queue.
/// Now acting as a thin wrapper (Presentation Logic) that delegates heavy lifting to DownloadService.
final downloadProvider = NotifierProvider<DownloadNotifier, List<DownloadItem>>(
  DownloadNotifier.new,
);

class DownloadNotifier extends Notifier<List<DownloadItem>> {
  StreamSubscription<DownloadUpdate>? _updateSubscription;

  @override
  List<DownloadItem> build() {
    final service = ref.watch(downloadServiceProvider);
    
    // Listen for updates from the service and apply them to our state
    _updateSubscription?.cancel();
    _updateSubscription = service.updateStream.listen((update) {
      _updateItem(update.id, update.updater);
      
      // Auto-schedule next if an item finishes or errors
      final item = state.cast<DownloadItem?>().firstWhere((i) => i?.id == update.id, orElse: () => null);
      if (item != null && (item.status == DownloadStatus.done || item.status == DownloadStatus.error)) {
        service.scheduleNext(state);
      }
    });

    ref.onDispose(() => _updateSubscription?.cancel());

    return [];
  }

  // ── Public API (Delegated to Service) ──────────────────────────────────────

  void addToQueue(
    List<String> urls, {
    DownloadType type = DownloadType.audio,
    DownloadSource source = DownloadSource.ytmusic,
    yt.Video? video,
  }) {
    final newItems = urls.map((url) => DownloadItem(
      id: video?.id.value ?? '${DateTime.now().microsecondsSinceEpoch}_${url.hashCode}',
      url: url,
      displayTitle: video?.title ?? url,
      type: type,
      source: source,
      video: video,
    )).toList();

    state = [...state, ...newItems];
    ref.read(downloadServiceProvider).scheduleNext(state);
  }

  void cancelItem(String id) {
    ref.read(downloadServiceProvider).cancelItem(id);
    // Note: status update will come back through the updateStream
  }

  void clearCompleted() {
    state = state.where((i) => 
      i.status != DownloadStatus.done && 
      i.status != DownloadStatus.error && 
      i.status != DownloadStatus.cancelled
    ).toList();
  }

  void retryItem(String id) {
    _updateItem(id, (item) => item.copyWith(
      status: DownloadStatus.queued, 
      progress: 0.0, 
      errorMessage: null, 
      logs: []
    ));
    ref.read(downloadServiceProvider).scheduleNext(state);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _updateItem(String id, DownloadItem Function(DownloadItem) updater) {
    state = [
      for (final item in state)
        if (item.id == id) updater(item) else item,
    ];
  }
}
