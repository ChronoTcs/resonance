import 'package:flutter/material.dart';
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

Future<void> _cleanSharedPreferences() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Clean Recently Played
    final recentList = prefs.getStringList('recently_played_items');
    if (recentList != null) {
      bool changed = false;
      final newList = recentList.map((itemStr) {
        final Map<String, dynamic> json = jsonDecode(itemStr);
        if (json.containsKey('albumArtBase64') && json['albumArtBase64'] != null) {
          json.remove('albumArtBase64');
          changed = true;
        }
        return jsonEncode(json);
      }).toList();
      
      if (changed) {
        await prefs.setStringList('recently_played_items', newList);
        print('Cleaned recently_played_items base64 footprint');
      }
    }

    // Clean Playlists
    final playlistsStr = prefs.getString('user_playlists');
    if (playlistsStr != null) {
      bool changed = false;
      final List<dynamic> playlistsList = jsonDecode(playlistsStr);
      for (var playlist in playlistsList) {
        final List<dynamic> tracks = playlist['tracks'] ?? [];
        for (var track in tracks) {
          if (track is Map<String, dynamic>) {
            if (track.containsKey('albumArtBase64') && track['albumArtBase64'] != null) {
              track.remove('albumArtBase64');
              changed = true;
            }
          }
        }
      }
      
      if (changed) {
        await prefs.setString('user_playlists', jsonEncode(playlistsList));
        print('Cleaned user_playlists base64 footprint');
      }
    }
  } catch (e) {
    print('Failed to clean SharedPreferences footprint: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize media_kit for high-performance cross-platform audio/video
  MediaKit.ensureInitialized();
  
  // Initialize SystemTheme for Windows Accent color
  if (Platform.isWindows) {
    await SystemTheme.accentColor.load();
  }

  // Aggressively clean up stale Base64 data to fix JSON 8MB write spikes
  await _cleanSharedPreferences();

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

  runApp(const ProviderScope(child: ResonanceApp()));
}

class ResonanceApp extends ConsumerStatefulWidget {
  const ResonanceApp({super.key});

  @override
  ConsumerState<ResonanceApp> createState() => _ResonanceAppState();
}

class _ResonanceAppState extends ConsumerState<ResonanceApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
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
      title: 'Resonance',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.getLightTheme(accentColor),
      darkTheme: AppTheme.getDarkTheme(accentColor),
      home: const MainDashboard(),
    );
  }
}
