

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

final rpcCacheServiceProvider = Provider<RpcCacheService>((ref) {
  return RpcCacheService(ref);
});

class RpcCacheService {
  final Ref _ref;
  RpcCacheService(this._ref);

  static const String _artCachePrefix = 'art_cache_';

  Future<String?> getCachedAlbumArtUrl(
    String artist, 
    String title, 
    Future<String?> Function() fetchFromITunes,
  ) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final key = '$_artCachePrefix${artist.toLowerCase()}_${title.toLowerCase()}';

    // Check cache
    final cachedUrl = prefs.getString(key);
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      return cachedUrl;
    }

    // Fetch and cache
    try {
      final url = await fetchFromITunes();
      if (url != null && url.isNotEmpty) {
        await prefs.setString(key, url);
      }
      return url;
    } catch (e) {
      print('Album art RPC cache/fetch error: $e');
      return null;
    }
  }

  Future<void> clearRpcCache() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final keys = prefs.getKeys().where((k) => k.startsWith(_artCachePrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
