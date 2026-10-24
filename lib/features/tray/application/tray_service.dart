import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:resonance/core/theme/theme_provider.dart';
import 'package:resonance/core/providers/overlay_provider.dart';
import 'package:resonance/features/stream/platform/windows/windows_po_token_service.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/core/application/providers/window_lifecycle_provider.dart';
import 'package:resonance/features/player/application/services/windows_system_media_service.dart';

/// Manages System Tray integration for Windows using native Win32 C++ runner channel.
class TrayService with WidgetsBindingObserver {
  final Ref _ref;
  bool _initialized = false;
  static const MethodChannel _channel =
      MethodChannel('com.chronostudio.resonance/system_tray');

  TrayService(this._ref);

  bool _resolveIsDark() {
    final mode = _ref.read(themeProvider);
    switch (mode) {
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.light:
        return false;
      case AppThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  /// Initializes the tray icon and context menu
  Future<void> initTray() async {
    if (!Platform.isWindows || _initialized) return;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onMenuItemSelected':
          final action = call.arguments as String?;
          if (action != null) {
            _onMenuItemSelected(action);
          }
          break;
        case 'onTrayIconClicked':
          await _restoreWindow();
          break;
        default:
          break;
      }
    });

    try {
      final isDark = _resolveIsDark();
      await _channel.invokeMethod('init', {'isDark': isDark});
      _initialized = true;

      // Register observer for platform brightness shifts
      WidgetsBinding.instance.addObserver(this);

      // Listen for app-level theme changes (Settings or TitleBar toggle)
      _ref.listen<AppThemeMode>(themeProvider, (previous, next) {
        updateTheme();
      });

      final audioState = _ref.read(audioProvider);
      await updateTrayMetadata(audioState.currentTrack, audioState.isPlaying);

      debugPrint('[TrayService] Initialized with adaptive Win32 tray (isDark: $isDark)');
    } catch (e, stack) {
      debugPrint('[TrayService] Failed to initialize native tray: $e\n$stack');
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_ref.read(themeProvider) == AppThemeMode.system) {
      updateTheme();
    }
  }

  /// Updates the tray context menu theme dynamically
  Future<void> updateTheme({bool? isDark}) async {
    if (!Platform.isWindows || !_initialized) return;
    final dark = isDark ?? _resolveIsDark();
    try {
      await _channel.invokeMethod('setTheme', {'isDark': dark});
    } catch (e) {
      debugPrint('[TrayService] Failed to update tray theme: $e');
    }
  }

  /// Dynamically updates metadata, playback status, and theme
  Future<void> updateTrayMetadata(MediaItem? currentTrack, bool isPlaying) async {
    if (!Platform.isWindows || !_initialized) return;

    final tooltip = currentTrack != null
        ? '${currentTrack.title} - ${currentTrack.artist ?? 'Unknown'}'
        : 'Resonance';

    final title = currentTrack?.title ?? '';

    try {
      await _channel.invokeMethod('updateMetadata', {
        'tooltip': tooltip,
        'title': title,
        'isPlaying': isPlaying,
        'isDark': _resolveIsDark(),
      });
    } catch (e) {
      debugPrint('[TrayService] Failed to update tray metadata: $e');
    }
  }

  /// Clears the tray icon before application shutdown
  Future<void> destroy() async {
    if (!Platform.isWindows || !_initialized) return;
    WidgetsBinding.instance.removeObserver(this);
    try {
      await _channel.invokeMethod('destroy');
    } catch (e) {
      debugPrint('[TrayService] Error destroying tray: $e');
    } finally {
      _initialized = false;
    }
  }

  void _onMenuItemSelected(String key) async {
    final audioNotifier = _ref.read(audioProvider.notifier);

    switch (key) {
      case 'open_now_playing':
        await _restoreWindow();
        _ref.read(nowPlayingOverlayProvider.notifier).setVisible(true);
        break;
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
    _ref.read(isWindowRenderActiveProvider.notifier).state = true;
    await windowManager.show();
    await windowManager.focus();
    // Rebuild thumbnail toolbar — Windows DWM destroys it when HWND is hidden.
    // syncTaskbarOnVisible() handles the 600ms DWM stabilization delay internally.
    _ref.read(windowsSystemMediaServiceProvider).syncTaskbarOnVisible();
  }

  Future<void> handleExit() async {
    WindowsPoTokenService().stop();
    await destroy();
    exit(0);
  }
}

/// Provider for TrayService
final trayServiceProvider = Provider<TrayService>((ref) {
  return TrayService(ref);
});
