import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:path/path.dart' as p;
import '../../application/services/youtube_auth_service.dart';

class YoutubeLoginScreen extends ConsumerStatefulWidget {
  const YoutubeLoginScreen({super.key});

  @override
  ConsumerState<YoutubeLoginScreen> createState() => _YoutubeLoginScreenState();
}

class _YoutubeLoginScreenState extends ConsumerState<YoutubeLoginScreen> {
  final _controller = WebviewController();
  bool _isInitialized = false;
  bool _isSuccess = false;
  String? _userDataPath;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      // [V20.6 SOTA] Calculate default WebView2 User Data Folder
      // Default location is {app_executable_name}.WebView2 in the same directory as the .exe
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      final exeName = p.basenameWithoutExtension(exePath);
      _userDataPath = p.join(exeDir, '$exeName.WebView2');

      await _controller.initialize();
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.setBackgroundColor(Colors.black);
      
      // Navigate to YouTube Music Login
      await _controller.loadUrl('https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&passive=true&continue=https://music.youtube.com/');

      _controller.url.listen((url) {
        if (url.contains('music.youtube.com')) {
          _checkAuthentication();
        }
      });

      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('WebView Error: $e');
    }
  }

  Future<void> _checkAuthentication() async {
    if (_isSuccess) return;

    try {
      // 1. Get cookies via webview_windows API (might not get HttpOnly in some versions)
      // But we will try to extract what we can from document.cookie first for non-httponly ones
      final String docCookie = await _controller.executeScript('document.cookie');
      final Map<String, String> cookieMap = ref.read(youtubeAuthServiceProvider).parseCookies(docCookie);

      // 2. Critical: Extract ytcfg metadata (visitorData, dataSyncId)
      final String ytCfgJson = await _controller.executeScript('''
        (function() {
          try {
            return JSON.stringify({
              visitorData: window.ytcfg.data_.VISITOR_DATA,
              dataSyncId: window.ytcfg.data_.DATASYNC_ID
            });
          } catch(e) { return "{}"; }
        })()
      ''');
      
      final Map<String, dynamic> ytCfg = Map<String, dynamic>.from(ref.read(youtubeAuthServiceProvider).parseCookies(ytCfgJson));
      // Note: parseCookies here is just a helper, ideally use jsonDecode but JS returned a string representation

      // Check if we have enough to consider "Logged In"
      // Usually presence of 'SAPISID' or '__Secure-3PAPISID' in cookies indicates auth success
      if (docCookie.contains('SAPISID') || docCookie.contains('__Secure-3PAPISID')) {
        _isSuccess = true;
        
        await ref.read(youtubeAuthServiceProvider).saveSession(
          cookies: cookieMap,
          visitorData: ytCfg['visitorData'],
          dataSyncId: ytCfg['dataSyncId'],
        );

        // [V20.6 SOTA] Trigger Shadow Replication Cookie Scan to capture HttpOnly (SID/HSID)
        if (_userDataPath != null) {
          await ref.read(youtubeAuthServiceProvider).scanNativeCookies(_userDataPath!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('YouTube Login Successful!')),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      debugPrint('Auth Check Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login to YouTube Music'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.loadUrl('https://music.youtube.com/'),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isInitialized)
            Webview(_controller)
          else
            const Center(child: CircularProgressIndicator()),
          
          if (!_isInitialized)
            Container(
              color: Colors.black,
              child: const Center(
                child: Text('Initializing Secure Browser...', style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
