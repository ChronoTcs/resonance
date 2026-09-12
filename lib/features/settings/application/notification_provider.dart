import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:window_manager/window_manager.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/core/providers/overlay_provider.dart';
import 'package:resonance/features/library/presentation/widgets/morphing_library_bar.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/settings/presentation/screens/settings_screen.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final bool isError;
  final String? targetScreen;
  final String? actionLabel;
  final VoidCallback? onAction;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.isError = false,
    this.targetScreen,
    this.actionLabel,
    this.onAction,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    bool? isError,
    String? targetScreen,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isError: isError ?? this.isError,
      targetScreen: targetScreen ?? this.targetScreen,
      actionLabel: actionLabel ?? this.actionLabel,
      onAction: onAction ?? this.onAction,
    );
  }
}

class NotificationState {
  final List<NotificationItem> items;
  final bool isDropdownVisible;

  NotificationState({
    required this.items,
    this.isDropdownVisible = false,
  });

  NotificationState copyWith({
    List<NotificationItem>? items,
    bool? isDropdownVisible,
  }) {
    return NotificationState(
      items: items ?? this.items,
      isDropdownVisible: isDropdownVisible ?? this.isDropdownVisible,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  @override
  NotificationState build() {
    _initNotifications();
    return NotificationState(items: []);
  }

  Future<void> _initNotifications() async {
    if (_isInitialized) return;

    try {
      if (Platform.isWindows) {
        const WindowsInitializationSettings initializationSettingsWindows =
            WindowsInitializationSettings(
          appName: 'Resonance',
          appUserModelId: 'ChronoTechs.Resonance.App',
          guid: 'e3d74cbb-5444-4828-98e3-b6d31de26ea8',
        );

        const InitializationSettings initializationSettings = InitializationSettings(
          windows: initializationSettingsWindows,
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        );

        await _localNotificationsPlugin.initialize(
          settings: initializationSettings,
          onDidReceiveNotificationResponse: (response) {
            handleNotificationClick(targetScreen: response.payload);
          },
        );
      } else if (Platform.isAndroid) {
        const AndroidInitializationSettings androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        await _localNotificationsPlugin.initialize(
          settings: const InitializationSettings(android: androidSettings),
          onDidReceiveNotificationResponse: (response) => handleNotificationClick(targetScreen: response.payload),
        );
        // Request POST_NOTIFICATIONS permission (Android 13+)
        await _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationNotifier] Local notifications plugin init skipped or unavailable: $e');
    }
  }

  Future<void> handleNotificationClick({String? targetScreen}) async {
    try {
      if (Platform.isWindows) {
        await windowManager.show();
        await windowManager.focus();
      }

      if (targetScreen == null) {
        state = state.copyWith(isDropdownVisible: true);
        return;
      }

      final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

      if (targetScreen == 'target:blocked_tracks') {
        ref.read(mainNavigationProvider.notifier).setIndex(5);
        ref.read(settingsSubViewProvider.notifier).setSubView(SettingsSubView.blocked);
      } else if (targetScreen == 'target:queue') {
        ref.read(queueOverlayProvider.notifier).setVisible(true);
      } else if (targetScreen == 'target:download') {
        if (isDesktop) {
          ref.read(mainNavigationProvider.notifier).setIndex(4);
        } else {
          ref.read(mainNavigationProvider.notifier).setIndex(2);
          ref.read(libraryNavModeProvider.notifier).setMode(LibraryNavMode.downloads);
        }
      } else if (targetScreen == 'target:library') {
        ref.read(mainNavigationProvider.notifier).setIndex(2);
        ref.read(libraryNavModeProvider.notifier).setMode(LibraryNavMode.music);
      } else if (targetScreen == 'target:playlists') {
        if (isDesktop) {
          ref.read(mainNavigationProvider.notifier).setIndex(3);
        } else {
          ref.read(mainNavigationProvider.notifier).setIndex(2);
          ref.read(libraryNavModeProvider.notifier).setMode(LibraryNavMode.playlists);
        }
      } else if (targetScreen.startsWith('target:playlist:')) {
        final playlistId = targetScreen.substring('target:playlist:'.length);
        if (isDesktop) {
          ref.read(mainNavigationProvider.notifier).setIndex(3);
        } else {
          ref.read(mainNavigationProvider.notifier).setIndex(2);
          ref.read(libraryNavModeProvider.notifier).setMode(LibraryNavMode.playlists);
        }
        ref.read(selectedPlaylistIdProvider.notifier).setSelectedId(playlistId);
      } else if (targetScreen.startsWith('target:settings')) {
        ref.read(mainNavigationProvider.notifier).setIndex(5);
        ref.read(settingsSubViewProvider.notifier).close();
      } else {
        state = state.copyWith(isDropdownVisible: true);
      }
    } catch (e) {
      debugPrint('[NotificationNotifier] Notification click restore failed: $e');
    }
  }

  Future<void> showNotification(
    String title,
    String message, {
    bool isError = false,
    String? target,
    String? actionLabel,
    VoidCallback? onAction,
    bool silentOsNotification = false,
  }) async {
    debugPrint('[Notification]${isError ? " [ERROR]" : ""} $title: $message');

    // 1. Add to in-app notification list
    final newItem = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
      isError: isError,
      targetScreen: target,
      actionLabel: actionLabel,
      onAction: onAction,
    );

    state = state.copyWith(items: [newItem, ...state.items]);

    if (silentOsNotification) return;

    // 2. Trigger native desktop notification on Windows
    if (Platform.isWindows && _isInitialized) {
      try {
        const WindowsNotificationDetails windowsDetails = WindowsNotificationDetails();
        const NotificationDetails platformDetails = NotificationDetails(
          windows: windowsDetails,
        );

        await _localNotificationsPlugin.show(
          id: newItem.id.hashCode,
          title: title,
          body: message,
          notificationDetails: platformDetails,
          payload: target,
        );
      } catch (e) {
        debugPrint('[NotificationNotifier] Windows local notification show failed: $e');
      }
    }

    // 3. Trigger native notification on Android
    if (Platform.isAndroid && _isInitialized) {
      try {
        final bool isDownload = (target != null && target.contains('download')) ||
            title.toLowerCase().contains('download');
        final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          isDownload ? 'resonance_downloads' : 'resonance_general',
          isDownload ? 'Download Notifications' : 'General Notifications',
          channelDescription: isDownload
              ? 'Resonance download progress and completion'
              : 'Resonance system alerts and general notifications',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
          autoCancel: true,
          showWhen: true,
        );

        final int notifId = newItem.id.hashCode & 0x7FFFFFFF;
        await _localNotificationsPlugin.show(
          id: notifId,
          title: title,
          body: message,
          notificationDetails: NotificationDetails(android: androidDetails),
          payload: target,
        );
      } catch (e) {
        debugPrint('[NotificationNotifier] Android local notification show failed: $e');
      }
    }
  }

  void markAllAsRead() {
    final updated = state.items.map((item) => item.copyWith(isRead: true)).toList();
    state = state.copyWith(items: updated);
  }

  void clearAll() {
    state = state.copyWith(items: []);
    if (_isInitialized) {
      _localNotificationsPlugin.cancelAll().catchError((e) {
        debugPrint('[NotificationNotifier] cancelAll failed: $e');
      });
    }
  }

  void removeItem(String id) {
    final updated = state.items.where((i) => i.id != id).toList();
    state = state.copyWith(items: updated);
    if (_isInitialized) {
      _localNotificationsPlugin.cancel(id: id.hashCode & 0x7FFFFFFF).catchError((e) {
        debugPrint('[NotificationNotifier] cancel failed: $e');
      });
    }
  }

  void toggleDropdown({bool? visible}) {
    state = state.copyWith(
      isDropdownVisible: visible ?? !state.isDropdownVisible,
    );
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, NotificationState>(() {
  return NotificationNotifier();
});
