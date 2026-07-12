import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:resonance/core/data/services/po_token_provider_service.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

/// Manages System Tray integration for Windows.
class TrayService with TrayListener {
  final Ref _ref;
  bool _initialized = false;

  TrayService(this._ref);

  /// Initializes the tray icon and context menu
  Future<void> initTray() async {
    if (!Platform.isWindows || _initialized) return;

    trayManager.addListener(this);

    await trayManager.setIcon(
      Platform.isWindows ? 'assets/icons/app_icon.ico' : 'assets/icons/app_icon.png',
    );

    await _buildInitialMenu();
    _initialized = true;

    final audioState = _ref.read(audioProvider);
    await updateTrayMetadata(audioState.currentTrack, audioState.isPlaying);

    debugPrint('[TrayService] Initialized');
  }

  /// Builds static initial tray menu
  Future<void> _buildInitialMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'now_playing',
          label: 'Resonance',
          disabled: true,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'play_pause',
          label: 'Play',
        ),
        MenuItem(
          key: 'skip_next',
          label: 'Next Track',
        ),
        MenuItem(
          key: 'skip_prev',
          label: 'Previous Track',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'restore',
          label: 'Open Resonance',
        ),
        MenuItem(
          key: 'exit',
          label: 'Exit',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  /// Dynamically updates metadata and play/pause status
  Future<void> updateTrayMetadata(MediaItem? currentTrack, bool isPlaying) async {
    if (!Platform.isWindows || !_initialized) return;

    final tooltip = currentTrack != null
        ? '${currentTrack.title} - ${currentTrack.artist ?? 'Unknown'}'
        : 'Resonance';
    await trayManager.setToolTip(tooltip);

    final menu = Menu(
      items: [
        MenuItem(
          key: 'now_playing',
          label: currentTrack != null ? '▶ ${currentTrack.title}' : 'Resonance',
          disabled: true,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'play_pause',
          label: isPlaying ? 'Pause' : 'Play',
        ),
        MenuItem(
          key: 'skip_next',
          label: 'Next Track',
        ),
        MenuItem(
          key: 'skip_prev',
          label: 'Previous Track',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'restore',
          label: 'Open Resonance',
        ),
        MenuItem(
          key: 'exit',
          label: 'Exit',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  /// Clears the tray icon before application shutdown
  Future<void> destroy() async {
    if (!Platform.isWindows) return;
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  @override
  void onTrayIconMouseDown() {
    _restoreWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final audioNotifier = _ref.read(audioProvider.notifier);

    switch (menuItem.key) {
      case 'play_pause':
        audioNotifier.togglePlayPause();
        break;
      case 'skip_next':
        audioNotifier.skipToNext();
        break;
      case 'skip_prev':
        audioNotifier.skipToPrevious();
        break;
      case 'restore':
        _restoreWindow();
        break;
      case 'exit':
        _handleExit();
        break;
    }
  }

  Future<void> _restoreWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _handleExit() async {
    poTokenProviderService.stop();
    await destroy();
    exit(0);
  }
}

/// Provider for TrayService
final trayServiceProvider = Provider<TrayService>((ref) {
  return TrayService(ref);
});
