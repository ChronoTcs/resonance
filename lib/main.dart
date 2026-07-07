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
import 'core/widgets/global_shortcut_wrapper.dart';
import 'core/data/services/storage_service.dart';
import 'core/configs/provider_observer.dart';
import 'features/player/presentation/widgets/floating_sniffer_bubble.dart';
import 'core/data/services/data_usage_service.dart';
import 'core/routing/route_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'features/player/application/audio_handler.dart';
import 'core/data/services/po_token_provider_service.dart';

import 'package:resonance_app/features/player/presentation/widgets/mini_player/floating/floating_window.dart';
import 'package:resonance_app/features/player/presentation/notifiers/mini_player_view_notifier.dart';

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
      // SOTA V11.0: Enhanced Database Resilience & Path Standard
      // Membantu mengatasi 'SQLITE_READONLY_DBMOVED' dengan mencari di folder sistem yang benar.
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
              // Hapus file jurnal SQLite agar tidak ada lock tersisa
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
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }
      // [SOTA V14.1] Mencegah aplikasi mati saat tombol close (X) ditekan
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

class _ResonanceAppState extends ConsumerState<ResonanceApp>
    with WindowListener {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) {
          ref.read(dataUsageServiceProvider).flush();
        }
      },
    );
  }

  @override
  void dispose() {
    poTokenProviderService.stop();
    _lifecycleListener.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResized() async {
    final popState = ref.read(miniPlayerPopProvider);
    if (popState.isPopped) return;

    final size = await windowManager.getSize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('window_width', size.width);
    await prefs.setDouble('window_height', size.height);
  }

  @override
  void onWindowMoved() async {
    final popState = ref.read(miniPlayerPopProvider);
    if (popState.isPopped) return;

    final pos = await windowManager.getPosition();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('window_x', pos.dx);
    await prefs.setDouble('window_y', pos.dy);
  }

  @override
  void onWindowClose() async {
    // [SOTA V14.1] Sembunyikan ke tray alih-alih menutup aplikasi
    if (Platform.isWindows) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final accentColor = ref.watch(accentColorProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [AppRouteObserver(ref)],
      title: 'Resonance',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.getLightTheme(accentColor),
      darkTheme: AppTheme.getDarkTheme(accentColor),
      scrollBehavior: FluentScrollBehavior(),
      builder: (context, child) {
        final content = Material(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Layer 1: Main Application Navigator (Base Layer)
              // We watch isPopped here to hide the main UI, but child! stays fresh outside Overlay.
              Consumer(
                builder: (context, ref, _) {
                  final isPopped = ref.watch(miniPlayerPopProvider).isPopped;
                  return Offstage(
                    offstage: isPopped,
                    child: OverflowBox(
                      minWidth: 0,
                      maxWidth: isPopped ? 4000 : null,
                      minHeight: 0,
                      maxHeight: isPopped ? 4000 : null,
                      alignment: Alignment.topLeft,
                      child: child!,
                    ),
                  );
                },
              ),

              // Layer 2: Sibling Global Overlay (Top Layer)
              // This provides the Overlay context for Tooltips and PiP without trapping the main app.
              Positioned.fill(
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) => Consumer(
                        builder: (context, ref, _) {
                          final isPopped = ref
                              .watch(miniPlayerPopProvider)
                              .isPopped;
                          return Material(
                            type: MaterialType.transparency,
                            child: Stack(
                              children: [
                                if (!Platform.isAndroid)
                                  const FloatingSnifferBubble(),

                                if (isPopped && Platform.isWindows)
                                  const FloatingWindow(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        if (Platform.isWindows) {
          return ExcludeSemantics(child: content);
        }
        return content;
      },
      home: const GlobalShortcutWrapper(child: MainDashboard()),
    );
  }
}
