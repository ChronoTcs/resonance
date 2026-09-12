class ThumbnailUtils {
  /// Upgrades low-resolution YouTube & YouTube Music thumbnail URLs to 1080p HD square artwork.
  static String upgradeResolution(String? url) {
    if (url == null || url.isEmpty) return '';

    // Upgrade YT Music thumbnail sizing parameters (=w60-h60, =w120-h120, =w226-h226, =w540-h540, =s60, etc.)
    String upgraded = url.replaceAll(RegExp(r'=w\d+-h\d+(?:-[a-z0-9-]+)?'), '=w1080-h1080-l90-rj')
                         .replaceAll(RegExp(r'=s\d+(?:-[a-z0-9-]+)?'), '=s1080');

    // Upgrade standard YouTube video thumbnail fallbacks (hqdefault.jpg -> maxresdefault.jpg)
    if (upgraded.contains('i.ytimg.com/vi/')) {
      upgraded = upgraded.replaceAll(RegExp(r'/(?:hq|mq|sd)?default\.jpg'), '/maxresdefault.jpg');
    }

    return upgraded;
  }

  /// Returns a safer medium-resolution fallback (e.g. s544 or hqdefault) if the 1080p asset fails with HTTP 500 / 404.
  static String? getFallbackResolution(String? url) {
    if (url == null || url.isEmpty) return null;

    if (url.contains('=w1080-h1080-l90-rj')) {
      return url.replaceAll('=w1080-h1080-l90-rj', '=w544-h544-l90-rj');
    }
    if (url.contains('=s1080')) {
      return url.replaceAll('=s1080', '=s544');
    }
    if (url.contains('maxresdefault.jpg')) {
      return url.replaceAll('maxresdefault.jpg', 'hqdefault.jpg');
    }
    return null;
  }
}
