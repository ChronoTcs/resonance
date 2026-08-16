import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:resonance/core/constants/app_constants.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';

/// Dynamic App Config model for remote URLs and dynamic app flags.
class AppConfig {
  final String donateUrl;
  final String bugReportUrl;
  final String repoUrl;
  final String releasesUrl;

  const AppConfig({
    required this.donateUrl,
    required this.bugReportUrl,
    required this.repoUrl,
    required this.releasesUrl,
  });

  factory AppConfig.defaults() {
    return const AppConfig(
      donateUrl: 'https://linktr.ee/Chronosz',
      bugReportUrl: AppConstants.githubIssuesUrl,
      repoUrl: AppConstants.githubRepoUrl,
      releasesUrl: AppConstants.githubReleasesUrl,
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      donateUrl: json['donate_url'] as String? ?? 'https://linktr.ee/Chronosz',
      bugReportUrl: json['bug_report_url'] as String? ?? AppConstants.githubIssuesUrl,
      repoUrl: json['repo_url'] as String? ?? AppConstants.githubRepoUrl,
      releasesUrl: json['releases_url'] as String? ?? AppConstants.githubReleasesUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'donate_url': donateUrl,
        'bug_report_url': bugReportUrl,
        'repo_url': repoUrl,
        'releases_url': releasesUrl,
      };
}

final appConfigProvider = NotifierProvider<AppConfigNotifier, AppConfig>(
  AppConfigNotifier.new,
);

class AppConfigNotifier extends Notifier<AppConfig> {
  static const String _storageKey = 'remote_app_config_json';

  @override
  AppConfig build() {
    // 1. Load cached config from SharedPreferences if available
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final cachedStr = prefs.getString(_storageKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(cachedStr);
        return AppConfig.fromJson(map);
      }
    } catch (e) {
      debugPrint('[AppConfig] Error reading local config cache: $e');
    }
    return AppConfig.defaults();
  }

  /// Fetches remote config from GitHub raw endpoint and updates state + cache.
  Future<void> fetchRemoteConfig() async {
    // Skip network request immediately if device is offline
    if (!ref.read(networkConnectivityProvider).isOnline) {
      debugPrint('[AppConfig] Device offline — using cached/default config.');
      return;
    }

    try {
      final response = await http
          .get(Uri.parse(AppConstants.githubRawConfigUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final newConfig = AppConfig.fromJson(json);
        state = newConfig;

        // Persist to SharedPreferences for offline fallback
        try {
          final prefs = ref.read(sharedPreferencesProvider);
          await prefs.setString(_storageKey, jsonEncode(newConfig.toJson()));
        } catch (_) {}

        debugPrint('[AppConfig] Successfully updated remote app config.');
      }
    } catch (e) {
      debugPrint('[AppConfig] Remote config fetch skipped/failed: $e');
    }
  }
}
