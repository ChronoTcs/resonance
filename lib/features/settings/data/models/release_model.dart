class AppRelease {
  final String tagName;
  final String name;
  final String body;
  final bool isPrerelease;
  final DateTime publishedAt;
  final List<dynamic> assets;
  final bool isCurrentVersion;
  final bool isNewerThanCurrent;
  final bool isOlderThanCurrent;

  AppRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.isPrerelease,
    required this.publishedAt,
    required this.assets,
    this.isCurrentVersion = false,
    this.isNewerThanCurrent = false,
    this.isOlderThanCurrent = false,
  });

  bool get isBeta {
    final lowerTag = tagName.toLowerCase();
    final lowerName = name.toLowerCase();
    return isPrerelease ||
        lowerTag.contains('beta') ||
        lowerTag.contains('rc') ||
        lowerTag.contains('alpha') ||
        lowerName.contains('beta') ||
        lowerName.contains('pre-release');
  }

  /// Finds matching delta patch asset specifically created from the currently installed version
  Map<String, dynamic>? getDeltaPatchAsset(String currentVersion) {
    // 1. NEVER use delta patching for downgrades or identical versions (prevents binary corruption)
    if (!isNewerThanCurrent) return null;

    final cleanCurrent = currentVersion.replaceAll(RegExp(r'^[vV]'), '').toLowerCase();
    for (var asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = asset['name'].toString().toLowerCase();
      if (name.endsWith('.patch')) {
        // 2. Strict matching: patch must be specifically built for the user's current version
        if (name.contains('-to-')) {
          final fromPart = name.split('-to-').first;
          if (fromPart.contains(cleanCurrent)) {
            return asset;
          }
        }
      }
    }
    return null;
  }

  /// Compares two version strings (e.g. '0.1.2-beta+3' vs '0.1.1-beta').
  /// Returns > 0 if v1 is newer than v2, < 0 if v1 is older than v2, and 0 if equal.
  static int compareSemVer(String v1, String v2) {
    List<int> parseNumeric(String v) {
      final sanitized = v.replaceAll(RegExp(r'^[vV]'), '').split('-')[0].split('+')[0];
      final parts = sanitized.split('.');
      return parts.map((p) => int.tryParse(p) ?? 0).toList();
    }

    final nums1 = parseNumeric(v1);
    final nums2 = parseNumeric(v2);

    final maxLen = nums1.length > nums2.length ? nums1.length : nums2.length;
    for (int i = 0; i < maxLen; i++) {
      final n1 = i < nums1.length ? nums1[i] : 0;
      final n2 = i < nums2.length ? nums2[i] : 0;
      if (n1 != n2) {
        return n1.compareTo(n2);
      }
    }

    // If base numeric parts (0.1.2 == 0.1.2) match, compare build numbers if present (+2 vs +3)
    int extractBuild(String v) {
      if (v.contains('+')) {
        final buildStr = v.split('+').last;
        return int.tryParse(buildStr) ?? 0;
      }
      return 0;
    }

    final b1 = extractBuild(v1);
    final b2 = extractBuild(v2);
    if (b1 != b2) {
      return b1.compareTo(b2);
    }

    return 0;
  }

  factory AppRelease.fromJson(Map<String, dynamic> json, String currentAppVersion) {
    final rawTag = json['tag_name'].toString();
    final cmp = compareSemVer(rawTag, currentAppVersion);
    final isCurrent = cmp == 0;
    final isNewer = cmp > 0;
    final isOlder = cmp < 0;

    return AppRelease(
      tagName: rawTag,
      name: (json['name'] != null && json['name'].toString().isNotEmpty)
          ? json['name'].toString()
          : rawTag,
      body: json['body']?.toString() ?? 'No release notes provided for this version.',
      isPrerelease: json['prerelease'] == true,
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? '') ?? DateTime.now(),
      assets: json['assets'] as List<dynamic>? ?? [],
      isCurrentVersion: isCurrent,
      isNewerThanCurrent: isNewer,
      isOlderThanCurrent: isOlder,
    );
  }

  AppRelease copyWith({
    bool? isCurrentVersion,
    bool? isNewerThanCurrent,
    bool? isOlderThanCurrent,
  }) {
    return AppRelease(
      tagName: tagName,
      name: name,
      body: body,
      isPrerelease: isPrerelease,
      publishedAt: publishedAt,
      assets: assets,
      isCurrentVersion: isCurrentVersion ?? this.isCurrentVersion,
      isNewerThanCurrent: isNewerThanCurrent ?? this.isNewerThanCurrent,
      isOlderThanCurrent: isOlderThanCurrent ?? this.isOlderThanCurrent,
    );
  }
}
