class ThumbnailUtils {
  /// Upgrades low-resolution YouTube & YouTube Music thumbnail URLs to 1080p HD square artwork.
  static String upgradeResolution(String? url) {
    if (url == null || url.isEmpty) return '';

    // Upgrade YT Music thumbnail sizing parameters (=w60-h60, =w120-h120, =w226-h226, =w540-h540, =s60, etc.)
    String upgraded = url.replaceAll(RegExp(r'=w\d+-h\d+(?:-[a-z0-9-]+)?'), '=w1080-h1080-l90-rj')
                         .replaceAll(RegExp(r'=s\d+(?:-[a-z0-9-]+)?'), '=s1080');

    // Upgrade standard YouTube video thumbnail fallbacks (hqdefault.jpg -> maxresdefault.jpg)
    if (upgraded.contains('i.ytimg.com/vi/')) {
      upgraded = upgraded.replaceAll(RegExp(r'/(hq|mq|sd|default)\.jpg'), '/maxresdefault.jpg');
    }

    return upgraded;
  }
}
