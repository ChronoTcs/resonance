import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/fluent_scroll_behavior.dart';

import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';
import 'dart:convert';
import 'package:resonance/features/dashboard/presentation/widgets/overlay_layer.dart';
import 'package:resonance/features/player/presentation/widgets/player_shortcut_wrapper.dart';
import 'core/data/services/storage_service.dart';
import 'core/configs/provider_observer.dart';

import 'core/routing/route_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'features/player/application/audio_handler.dart';
import 'core/data/services/po_token_provider_service.dart';
import 'package:resonance/features/settings/application/startup_service.dart';
import 'package:resonance/core/application/services/window_persistence_service.dart';
import 'package:resonance/core/application/services/lifecycle_service.dart';

Future<void> _cleanSharedPreferences() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Bypass if already cleaned in this version
    const cleanFlag = 'json_cleanup_v2';
    if (prefs.getBool(cleanFlag) ?? false) return;

    final recentList = prefs.getStringList('recently_played_items');
    final playlistsStr = prefs.getString('user_playlists');

    final results = await compute(_performCleanupIsolate, {
      'recentList': recentList,
      'playlistsStr': playlistsStr,
    });

    if (results['recentChanged'] == true) {
      final List<dynamic> cleanedList = results['recentList'] as List<dynamic>;
      await prefs.setStringList(
        'recently_played_items',
        cleanedList.cast<String>(),
      );
    }
    if (results['playlistsChanged'] == true) {
      await prefs.setString(
        'user_playlists',
        results['playlistsStr'] as String,
      );
    }

    if (Platform.isAndroid) {
      // Helps resolve 'SQLITE_READONLY_DBMOVED' by locating the correct system folder.
      final docDir = await getApplicationDocumentsDirectory();
      final androidBase = docDir.parent.path; // /data/user/0/<pkg>/

      final dbLocations = [
        p.join(androidBase, 'databases', 'libCachedImageData.db'),
        p.join(androidBase, 'files', 'libCachedImageData.db'),
      ];

      final fixedKey = 'image_cache_fixed_v2';
      if (!(prefs.getBool(fixedKey) ?? false)) {
        for (final path in dbLocations) {
          final dbFile = File(path);
          if (await dbFile.exists()) {
            try {
              await dbFile.delete();
              // Delete SQLite journal files to clear residual locks
              await File('$path-wal').delete().catchError((_) => File(''));
              await File('$path-shm').delete().catchError((_) => File(''));
              debugPrint('Cleanup: Deleted legacy cache DB at $path');
            } catch (e) {
              debugPrint('Cleanup: Non-fatal error deleting DB at $path: $e');
            }
          }
        }
        await prefs.setBool(fixedKey, true);
      }
    }

    await prefs.setBool(cleanFlag, true);
  } catch (e) {
    debugPrint('Failed to clean SharedPreferences footprint: $e');
  }
}

Map<String, dynamic> _performCleanupIsolate(Map<String, dynamic> data) {
  final List<String>? recentList = data['recentList'] as List<String>?;
  final String? playlistsStr = data['playlistsStr'] as String?;

  bool recentChanged = false;
  List<String> newRecentList = [];
  if (recentList != null) {
    newRecentList = recentList.map((itemStr) {
      try {
        final Map<String, dynamic> json = jsonDecode(itemStr);
        if (json.containsKey('albumArtBase64') &&
            json['albumArtBase64'] != null) {
          json.remove('albumArtBase64');
          recentChanged = true;
        }
        return jsonEncode(json);
      } catch (e) {
        return itemStr;
      }
    }).toList();
  }

  bool playlistsChanged = false;
  String newPlaylistsStr = playlistsStr ?? '';
  if (playlistsStr != null) {
    try {
      final List<dynamic> playlistsList = jsonDecode(playlistsStr);
      for (var playlist in playlistsList) {
        final List<dynamic> tracks = playlist['tracks'] ?? [];
        for (var track in tracks) {
          if (track is Map<String, dynamic>) {
            if (track.containsKey('albumArtBase64') &&
                track['albumArtBase64'] != null) {
              track.remove('albumArtBase64');
              playlistsChanged = true;
            }
          }
        }
      }
      if (playlistsChanged) {
        newPlaylistsStr = jsonEncode(playlistsList);
      }
    } catch (e) {
      debugPrint('Cleanup Isolate: Error parsing playlist JSON: $e');
    }
  }

  return {
    'recentChanged': recentChanged,
    'recentList': newRecentList,
    'playlistsChanged': playlistsChanged,
    'playlistsStr': newPlaylistsStr,
  };
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  debugPrint('Resonance: Starting main()...');
  WidgetsFlutterBinding.ensureInitialized();

  await poTokenProviderService.start();





  MediaKit.ensureInitialized();

  final player = Player(configuration: const PlayerConfiguration(pitch: true));

  if (Platform.isAndroid) {
    Future.microtask(() async {
      try {
        await (player.platform as dynamic).setProperty('ao', 'audiotrack');
        debugPrint('Audio Engine: Switched output backend to audiotrack');
      } catch (e) {
        debugPrint('Audio Engine: Failed to switch output backend: $e');
      }
    });
  }

  final audioHandler = await AudioService.init(
    builder: () => ResonanceAudioHandler(player),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.resonance.audio',
      androidNotificationChannelName: 'Resonance Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (Platform.isWindows) {
    await SystemTheme.accentColor.load();
  }

  Future.microtask(() {
    _cleanSharedPreferences();
  });

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    windowManager.addListener(AppWindowStyleListener());
    final prefs = await SharedPreferences.getInstance();

    final width = prefs.getDouble('window_width') ?? 1280;
    final height = prefs.getDouble('window_height') ?? 720;
    final x = prefs.getDouble('window_x');
    final y = prefs.getDouble('window_y');

    WindowOptions windowOptions = WindowOptions(
      size: Size(width, height),
      center: x == null,
      minimumSize: const Size(800, 600),
      title: 'Resonance',
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      observers: [AppProviderObserver()],
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const ResonanceApp(),
    ),
  );
}

class ResonanceApp extends ConsumerStatefulWidget {
  const ResonanceApp({super.key});

  @override
  ConsumerState<ResonanceApp> createState() => _ResonanceAppState();
}

class _ResonanceAppState extends ConsumerState<ResonanceApp> {
  late final WindowPersistenceService _windowService;
  late final AppLifecycleService _lifecycleService;

  @override
  void initState() {
    super.initState();
    _windowService = WindowPersistenceService(ref);
    _lifecycleService = AppLifecycleService(ref);
    windowManager.addListener(_windowService);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await runStartupChecks(ref);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(_windowService);
    _lifecycleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appThemeMode = ref.watch(themeProvider);
    final accentColor = ref.watch(accentColorProvider);

    ThemeMode resolvedThemeMode;
    switch (appThemeMode) {
      case AppThemeMode.light:
        resolvedThemeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
      case AppThemeMode.onyx:
        resolvedThemeMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        resolvedThemeMode = ThemeMode.system;
        break;
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [AppRouteObserver(ref)],
      title: 'Resonance',
      debugShowCheckedModeBanner: false,
      themeMode: resolvedThemeMode,
      theme: AppTheme.getLightTheme(accentColor),
      darkTheme: AppTheme.getDarkTheme(accentColor, isOnyx: appThemeMode == AppThemeMode.onyx),
      scrollBehavior: FluentScrollBehavior(),
      builder: (context, child) => OverlayLayer(child: child!),
      home: const PlayerShortcutWrapper(child: MainDashboard()),
    );
  }
}
