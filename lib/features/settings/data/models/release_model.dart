class AppRelease {
  final String tagName;
  final String name;
  final String body;
  final bool isPrerelease;
  final DateTime publishedAt;
  final List<dynamic> assets;
  final bool isCurrentVersion;

  AppRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.isPrerelease,
    required this.publishedAt,
    required this.assets,
    this.isCurrentVersion = false,
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

  factory AppRelease.fromJson(Map<String, dynamic> json, String currentAppVersion) {
    final rawTag = json['tag_name'].toString();
    final cleanTag = rawTag.replaceAll('v', '').split('+')[0].trim();
    final cleanCurrent = currentAppVersion.replaceAll('v', '').split('+')[0].trim();

    return AppRelease(
      tagName: rawTag,
      name: (json['name'] != null && json['name'].toString().isNotEmpty)
          ? json['name'].toString()
          : rawTag,
      body: json['body']?.toString() ?? 'No release notes provided for this version.',
      isPrerelease: json['prerelease'] == true,
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? '') ?? DateTime.now(),
      assets: json['assets'] as List<dynamic>? ?? [],
      isCurrentVersion: cleanTag == cleanCurrent,
    );
  }

  AppRelease copyWith({bool? isCurrentVersion}) {
    return AppRelease(
      tagName: tagName,
      name: name,
      body: body,
      isPrerelease: isPrerelease,
      publishedAt: publishedAt,
      assets: assets,
      isCurrentVersion: isCurrentVersion ?? this.isCurrentVersion,
    );
  }
}
