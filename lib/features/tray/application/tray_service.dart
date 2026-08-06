import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nativeapi/nativeapi.dart' as napi;
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import 'package:resonance/core/data/services/po_token_provider_service.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

/// Manages System Tray integration for Windows using nativeapi.
class TrayService {
  final Ref _ref;
  bool _initialized = false;
  napi.TrayIcon? _trayIcon;

  TrayService(this._ref);

  /// Initializes the tray icon and context menu
  Future<void> initTray() async {
    if (!Platform.isWindows || _initialized) return;

    _trayIcon = napi.TrayIcon();

    // 1. Try resolving from executable bundle assets
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final bundlePngPath = p.join(exeDir, 'data', 'flutter_assets', 'assets', 'icons', 'app_icon.png');
    final bundleIcoPath = p.join(exeDir, 'data', 'flutter_assets', 'assets', 'icons', 'app_icon.ico');

    // 2. Try resolving from absolute project source tree (for local flutter run debug sessions)
    final projectPngPath = p.join(Directory.current.path, 'assets', 'icons', 'app_icon.png');
    final projectIcoPath = p.join(Directory.current.path, 'assets', 'icons', 'app_icon.ico');

    napi.Image? iconImage;
    for (final pathCandidate in [bundlePngPath, bundleIcoPath, projectPngPath, projectIcoPath]) {
      if (File(pathCandidate).existsSync()) {
        iconImage = napi.Image.fromFile(pathCandidate);
        if (iconImage != null) {
          debugPrint('[TrayService] Successfully loaded nativeapi tray icon from: $pathCandidate');
          break;
        }
      }
    }

    iconImage ??= napi.Image.fromAsset('assets/icons/app_icon.png');

    if (iconImage != null) {
      _trayIcon!.icon = iconImage;
    } else {
      debugPrint('[TrayService] ERROR: All nativeapi icon load attempts failed.');
    }

    _trayIcon!.contextMenuTrigger = napi.ContextMenuTrigger.rightClicked;
    _trayIcon!.isVisible = true;

    _trayIcon!.on<napi.TrayIconClickedEvent>((_) {
      _restoreWindow();
    });

    await _buildInitialMenu();
    _initialized = true;

    final audioState = _ref.read(audioProvider);
    await updateTrayMetadata(audioState.currentTrack, audioState.isPlaying);

    debugPrint('[TrayService] Initialized with nativeapi');
  }

  /// Builds static initial tray menu
  Future<void> _buildInitialMenu() async {
    if (_trayIcon == null) return;

    final menu = napi.Menu();
    final nowPlayingItem = napi.MenuItem('Resonance')..enabled = false;
    menu.addItem(nowPlayingItem);
    menu.addSeparator();

    final playItem = napi.MenuItem('Play');
    playItem.on<napi.MenuItemClickedEvent>((_) => _onMenuItemSelected('play_pause'));
    menu.addItem(playItem);

    final nextItem = napi.MenuItem('Next Track');
    nextItem.on<napi.MenuItemClickedEvent>((_) => _onMenuItemSelected('skip_next'));
    menu.addItem(nextItem);

    final prevItem = napi.MenuItem('Previous Track');
    prevItem.on<napi.MenuItemClickedEvent>((_) => _onMenuItemSelected('skip_prev'));
    menu.addItem(prevItem);

    menu.addSeparator();

    final restoreItem = napi.MenuItem('Open Resonance');
    restoreItem.on<napi.MenuItemClickedEvent>((_) => _onMenuItemSelected('restore'));
    menu.addItem(restoreItem);

    final exitItem = napi.MenuItem('Exit');
    exitItem.on<napi.MenuItemClickedEvent>((_) => _onMenuItemSelected('exit'));
    menu.addItem(exitItem);

    _trayIcon!.contextMenu = menu;
  }

  /// Dynamically updates metadata and play/pause status
  Future<void> updateTrayMetadata(MediaItem? currentTrack, bool isPlaying) async {
    if (!Platform.isWindows || !_initialized || _trayIcon == null) return;

    final tooltip = currentTrack != null
        ? '${currentTrack.title} - ${currentTrack.artist ?? 'Unknown'}'
        : 'Resonance';
    _trayIcon!.tooltip = tooltip;

    final menu = napi.Menu();
    final nowPlayingItem = napi.MenuItem(currentTrack != null ? '▶ ${currentTrack.title}' : 'Resonance')..enabled = false;
    menu.addItem(nowPlayingItem);
    menu.addSeparator();

    final playItem = napi.MenuItem(isPlaying ? 'Pause' : 'Play');
    playItem.on<napi.MenuItemClickedEvent>((_) => _onMenuItemSelected('play_pause'));
    menu.addItem(playItem);

    final nextItem = napi.MenuItem('Next Track');
    nextItem.on<napi.MenuItemClickedEvent>((_) => _onMenuItemSelected('skip_next'));
    menu.addItem(nextItem);

    final prevItem = napi.MenuItem('Previous Track');
    prevItem.on<napi.MenuItemClickedEvent>((_) => _onMenuItemSelected('skip_prev'));
    menu.addItem(prevItem);

    menu.addSeparator();

    final restoreItem = napi.MenuItem('Open Resonance');
    restoreItem.on<napi.MenuItemClickedEvent>((_) => _onMenuItemSelected('restore'));
    menu.addItem(restoreItem);

    final exitItem = napi.MenuItem('Exit');
    exitItem.on<napi.MenuItemClickedEvent>((_) => _onMenuItemSelected('exit'));
    menu.addItem(exitItem);

    _trayIcon!.contextMenu = menu;
  }

  /// Clears the tray icon before application shutdown
  Future<void> destroy() async {
    if (!Platform.isWindows || _trayIcon == null) return;
    _trayIcon!.dispose();
    _trayIcon = null;
  }

  void _onMenuItemSelected(String key) {
    final audioNotifier = _ref.read(audioProvider.notifier);

    switch (key) {
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
        handleExit();
        break;
    }
  }

  Future<void> _restoreWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> handleExit() async {
    poTokenProviderService.stop();
    await destroy();
    exit(0);
  }
}

/// Provider for TrayService
final trayServiceProvider = Provider<TrayService>((ref) {
  return TrayService(ref);
});
