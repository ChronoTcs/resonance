import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/player/presentation/screens/main_dashboard.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';
import 'dart:convert';
import 'core/widgets/global_shortcut_wrapper.dart';
import 'core/services/storage_service.dart';
import 'core/services/provider_observer.dart';
import 'features/player/presentation/widgets/floating_sniffer_bubble.dart';
import 'core/services/data_usage_service.dart';
import 'core/services/route_provider.dart';
import 'core/services/permission_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'features/player/application/audio_handler.dart';

Future<void> _cleanSharedPreferences() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Bypass if already cleaned in this version
    const cleanFlag = 'json_cleanup_v2';
    if (prefs.getBool(cleanFlag) ?? false) {
      print('Resonance: JSON cleanup already completed. Skipping.');
      return;
    }

    print('Resonance: Starting heavy JSON cleanup in background...');
    
    final recentList = prefs.getStringList('recently_played_items');
    final playlistsStr = prefs.getString('user_playlists');

    // Use compute for the heavy lifting
    final results = await compute(_performCleanupIsolate, {
      'recentList': recentList,
      'playlistsStr': playlistsStr,
    });

    if (results['recentChanged'] == true) {
      final List<dynamic> cleanedList = results['recentList'] as List<dynamic>;
      await prefs.setStringList('recently_played_items', cleanedList.cast<String>());
    }
    if (results['playlistsChanged'] == true) {
      await prefs.setString('user_playlists', results['playlistsStr'] as String);
    }

    // NEW: Fix libCachedImageData.db corruption (table already exists error)
    if (Platform.isAndroid) {
      final docDir = await getApplicationDocumentsDirectory();
      final filesPath = p.join(docDir.parent.path, 'files');
      final dbPath = p.join(filesPath, 'libCachedImageData.db');
      final dbFile = File(dbPath);
      
      if (await dbFile.exists()) {
        final fixedKey = 'image_cache_fixed_v1';
        if (!(prefs.getBool(fixedKey) ?? false)) {
          await dbFile.delete().catchError((_) => dbFile);
          await File('$dbPath-wal').delete().catchError((_) => File(''));
          await File('$dbPath-shm').delete().catchError((_) => File(''));
          await prefs.setBool(fixedKey, true);
          print('Resonance: Reset corrupted image cache database');
        }
      }
    }

    await prefs.setBool(cleanFlag, true);
    print('Resonance: JSON cleanup finished.');
  } catch (e) {
    print('Failed to clean SharedPreferences footprint: $e');
  }
}

/// Isolate-safe cleanup function
Map<String, dynamic> _performCleanupIsolate(Map<String, dynamic> data) {
  final List<String>? recentList = data['recentList'] as List<String>?;
  final String? playlistsStr = data['playlistsStr'] as String?;
  
  bool recentChanged = false;
  List<String> newRecentList = [];
  if (recentList != null) {
    newRecentList = recentList.map((itemStr) {
      try {
        final Map<String, dynamic> json = jsonDecode(itemStr);
        if (json.containsKey('albumArtBase64') && json['albumArtBase64'] != null) {
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
            if (track.containsKey('albumArtBase64') && track['albumArtBase64'] != null) {
              track.remove('albumArtBase64');
              playlistsChanged = true;
            }
          }
        }
      }
      if (playlistsChanged) {
        newPlaylistsStr = jsonEncode(playlistsList);
      }
    } catch (e) {}
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
  print('Resonance: Starting main()...');
  WidgetsFlutterBinding.ensureInitialized();
  print('Resonance: Flutter initialized.');
  
  // Initialize media_kit for high-performance cross-platform audio/video
  MediaKit.ensureInitialized();
  print('Resonance: MediaKit initialized.');

  // Create shared player for AudioService and App State
  final player = Player(
    configuration: const PlayerConfiguration(
      pitch: true,
    ),
  );

  print('Resonance: Initializing AudioService...');
  final audioHandler = await AudioService.init(
    builder: () => ResonanceAudioHandler(player),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.resonance.audio',
      androidNotificationChannelName: 'Resonance Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  print('Resonance: AudioService initialized.');
  
  // Lock orientation to portrait for Android/iOS
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize SystemTheme for Windows Accent color
  if (Platform.isWindows) {
    await SystemTheme.accentColor.load();
  }

  // Aggressively clean up stale Base64 data to fix JSON 8MB write spikes
  // Moving to non-blocking to prevent splash hang
  Future.microtask(() {
    print('Resonance: Background cleanup started.');
    _cleanSharedPreferences();
  });

  // Initialize window_manager for persistence
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    
    // Load saved window state
    final width = prefs.getDouble('window_width') ?? 900;
    final height = prefs.getDouble('window_height') ?? 700;
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
      await windowManager.show();
      await windowManager.focus();
    });
  }

  print('Resonance: Fetching SharedPreferences...');
  final prefs = await SharedPreferences.getInstance();
  print('Resonance: SharedPreferences ready.');

  print('Resonance: Calling runApp()...');
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

class FluentScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Force Clamping globally to prevent the "Stretch" effect that distorts text
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Disable the "Stretch" glow/indicator entirely for a cleaner feel
    return child;
  }
}

class ResonanceApp extends ConsumerStatefulWidget {
  const ResonanceApp({super.key});

  @override
  ConsumerState<ResonanceApp> createState() => _ResonanceAppState();
}

class _ResonanceAppState extends ConsumerState<ResonanceApp> with WindowListener {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    
    // OS Lifecycle Guarding: Flush usage data on background/force-close
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.hidden || 
            state == AppLifecycleState.paused || 
            state == AppLifecycleState.detached) {
          ref.read(dataUsageServiceProvider).flush();
        }
      },
    );

    // Initial Permission Request for Android
    Future.delayed(const Duration(seconds: 1), () {
      if (context.mounted) {
        PermissionService.requestInitialPermissions(context);
      }
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResized() async {
    final size = await windowManager.getSize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('window_width', size.width);
    await prefs.setDouble('window_height', size.height);
  }

  @override
  void onWindowMoved() async {
    final pos = await windowManager.getPosition();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('window_x', pos.dx);
    await prefs.setDouble('window_y', pos.dy);
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
      scrollBehavior: FluentScrollBehavior(), // Apply global themed scrollbars
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            if (!Platform.isAndroid) const FloatingSnifferBubble(),
          ],
        );
      },
      home: const GlobalShortcutWrapper(child: MainDashboard()),
    );
  }
}
