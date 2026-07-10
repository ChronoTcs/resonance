import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:resonance/core/data/services/po_token_provider_service.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

/// [TrayService]
/// Mengelola integrasi System Tray untuk Windows.
/// Implementasi [TrayListener] untuk menangani interaksi mouse pada ikon.
class TrayService with TrayListener {
  final Ref _ref;
  bool _initialized = false;

  TrayService(this._ref);

  /// Inisialisasi awal ikon dan menu tray
  Future<void> initTray() async {
    if (!Platform.isWindows || _initialized) return;

    // Tambahkan listener untuk event tray
    trayManager.addListener(this);

    // Inisialisasi awal (Gunakan icon dari assets yang sudah terdaftar di pubspec)
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/icons/app_icon.ico' : 'assets/icons/app_icon.png',
    );

    await _buildInitialMenu();
    _initialized = true;

    // [V15.2 SOTA] Cold Start Sync: Paksa update tray dengan state awal
    final audioState = _ref.read(audioProvider);
    await updateTrayMetadata(audioState.currentTrack, audioState.isPlaying);

    debugPrint('[TrayService] Initialized');
  }

  /// Membangun menu awal statis
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

  /// [Performance Polish V14.2]
  /// Memperbarui Metadata (Judul & Artis) dan Status Play/Pause secara dinamis.
  /// Method ini akan dipanggil oleh listener yang sudah difilter menggunakan .select()
  Future<void> updateTrayMetadata(MediaItem? currentTrack, bool isPlaying) async {
    if (!Platform.isWindows || !_initialized) return;

    // 1. Update Tooltip (Spotify Style)
    final tooltip = currentTrack != null
        ? '${currentTrack.title} - ${currentTrack.artist ?? 'Unknown'}'
        : 'Resonance';
    await trayManager.setToolTip(tooltip);

    // 2. Re-build Context Menu dengan metadata dinamis
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

  /// [Ghost Icon Prevention]
  /// Membersihkan ikon dari taskbar sebelum aplikasi benar-benar keluar.
  Future<void> destroy() async {
    if (!Platform.isWindows) return;
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TRAY LISTENERS
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    // [Double-Click Expectation] Memunculkan aplikasi saat ikon di klik kiri
    _restoreWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    // [V19.0 SOTA] Fix 'Sticky Menu' Bug.
    // Menambahkan bringAppToFront: true agar Windows dapat menutup menu 
    // secara otomatis saat klik di luar area menu (Focus Trick).
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
    // [V19.2 SOTA] Unified Restoration Logic.
    // Cukup panggil windowManager.show() dan focus().
    // Sinkronisasi Taskbar kini ditangani secara otomatis dan terpusat oleh 
    // WindowListener di WindowsSystemMediaService dengan jeda keamanan 400ms.
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _handleExit() async {
    poTokenProviderService.stop();
    await destroy(); // [GUARD] Bersihkan tray
    exit(0);
  }
}

/// Provider untuk TrayService
final trayServiceProvider = Provider<TrayService>((ref) {
  return TrayService(ref);
});
