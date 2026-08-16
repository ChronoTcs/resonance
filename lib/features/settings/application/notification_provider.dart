import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:window_manager/window_manager.dart';
import 'package:resonance/core/providers/navigation_provider.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final bool isError;
  final String? targetScreen;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.isError = false,
    this.targetScreen,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    bool? isError,
    String? targetScreen,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isError: isError ?? this.isError,
      targetScreen: targetScreen ?? this.targetScreen,
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

    if (Platform.isWindows) {
      const WindowsInitializationSettings initializationSettingsWindows =
          WindowsInitializationSettings(
        appName: 'Resonance',
        appUserModelId: 'ChronoTechs.Resonance.App',
        guid: 'e3d74cbb-5444-4828-98e3-b6d31de26ea8',
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        windows: initializationSettingsWindows,
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
  }

  Future<void> handleNotificationClick({String? targetScreen}) async {
    try {
      if (Platform.isWindows) {
        await windowManager.show();
        await windowManager.focus();
      }
      
      if (targetScreen == 'target:download') {
        ref.read(mainNavigationProvider.notifier).setIndex(4);
      } else if (targetScreen == 'target:settings') {
        ref.read(mainNavigationProvider.notifier).setIndex(5);
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
    );

    state = state.copyWith(items: [newItem, ...state.items]);

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
        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'resonance_downloads',
          'Download Notifications',
          channelDescription: 'Resonance download progress and completion',
          importance: Importance.high,
          priority: Priority.high,
        );
        await _localNotificationsPlugin.show(
          id: newItem.id.hashCode,
          title: title,
          body: message,
          notificationDetails: const NotificationDetails(android: androidDetails),
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
