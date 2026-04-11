import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../../../core/data/services/cache_manager.dart';
import 'youtube_js_worker.dart';

final youtubeJsEngineProvider = Provider<YoutubeJsEngine>((ref) {
  final cacheManager = ref.watch(cacheManagerProvider);
  final engine = YoutubeJsEngine(cacheManager);
  ref.onDispose(() => engine.dispose());
  return engine;
});

class YoutubeJsEngine {
  final CacheManager _cacheManager;
  final JavascriptRuntime _jsRuntime;
  bool _isInitialized = false;
  String? _nFunctionName;
  int? _signatureTimestamp; 
  
  // [V20.7 SOTA Patch] Initialization Lock Future to prevent concurrent downloads
  Future<void>? _initFuture;

  YoutubeJsEngine(this._cacheManager) : _jsRuntime = getJavascriptRuntime();

  void dispose() {
    _jsRuntime.dispose();
  }

  /// Returns the cached signature timestamp or null if not loaded.
  Future<int?> getSignatureTimestamp(String baseJsUrl) async {
    try {
      await _ensureInitialized(baseJsUrl);
      return _signatureTimestamp;
    } catch (_) {
      return null;
    }
  }

  /// Ensures that the JS engine is loaded with the latest base.js and ready to decipher.
  Future<void> _ensureInitialized(String baseJsUrl) async {
    if (_isInitialized && _nFunctionName != null && _signatureTimestamp != null) return;
    
    // [V20.7 SOTA Patch] Use existing future if initialization is in progress
    return _initFuture ??= _performInitialization(baseJsUrl).catchError((e) {
      _initFuture = null; // Clear on error so we can retry later
      throw e;
    });
  }

  Future<void> _performInitialization(String baseJsUrl) async {
    try {
      final dir = await _cacheManager.getMetadataDir();
      final file = File(p.join(dir.path, 'youtube_base_js.js'));

      String jsCode;
      bool shouldDownload = true;

      // Check cache validity (24 hours)
      if (await file.exists()) {
        final stat = await file.stat();
        if (DateTime.now().difference(stat.modified).inHours < 24) {
          shouldDownload = false;
        }
      }

      if (shouldDownload) {
        debugPrint('YoutubeJsEngine: Downloading base.js from $baseJsUrl');
        
        final response = await http.get(
          Uri.parse(baseJsUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
          },
        );
        
        if (response.statusCode == 200) {
          jsCode = response.body;
          await file.writeAsString(jsCode);
        } else {
          throw Exception('Failed to download base.js: ${response.statusCode}');
        }
      } else {
        jsCode = await file.readAsString();
      }
      
      // [V20.12 SOTA Patch] Enhanced STS Extraction (Global Compatibility)
      // Handles both long (signatureTimestamp:123) and short (sts:123) formats.
      final stsMatch = RegExp(r'(?:signatureTimestamp|sts):(\d+)').firstMatch(jsCode);
      if (stsMatch != null) {
        _signatureTimestamp = int.tryParse(stsMatch.group(1)!);
        debugPrint('YoutubeJsEngine: Extracted STS: $_signatureTimestamp');
      }

      // [V20.6 SOTA] Use Background Isolate Worker for Deep Extraction (N-Decipher)
      debugPrint('YoutubeJsEngine: Starting Deep Extraction in background isolate...');
      final routine = await YoutubeJsWorker.extractDecipherRoutine(jsCode);
      
      if (routine.isFallback || routine.code.isEmpty) {
        debugPrint('YoutubeJsEngine: [PLAN B] Deep extraction failed. Fallback to raw N.');
        return;
      }

      _nFunctionName = routine.functionName;
      _jsRuntime.evaluate(routine.code);
      _isInitialized = true;
      debugPrint('YoutubeJsEngine: Initialization SUCCESS.');
      
    } catch (e) {
      debugPrint('YoutubeJsEngine: Initialization ERROR: $e');
      rethrow;
    }
  }

  /// Deciphers the 'n' parameter to bypass throttling.
  Future<String> decipherN(String n, String baseJsUrl) async {
    try {
      await _ensureInitialized(baseJsUrl);
    } catch (_) {
      return n;
    }
    
    if (!_isInitialized || _nFunctionName == null) {
      return n;
    }

    try {
      final result = _jsRuntime.evaluate('$_nFunctionName("$n")');
      return result.stringResult;
    } catch (e) {
      debugPrint('YoutubeJsEngine: Decipher ERROR: $e');
      return n;
    }
  }
}
