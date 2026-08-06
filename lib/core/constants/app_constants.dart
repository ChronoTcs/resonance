abstract class AppConstants {
  static const String githubOwner = 'ChronoTechs';
  static const String githubRepo = 'resonance';

  static const String githubRepoUrl = 'https://github.com/$githubOwner/$githubRepo';
  static const String githubIssuesUrl = '$githubRepoUrl/issues';
  static const String githubReleasesUrl = '$githubRepoUrl/releases';
  static const String githubReleasesApiUrl = 'https://api.github.com/repos/$githubOwner/$githubRepo/releases';
  static const String githubRawConfigUrl = 'https://raw.githubusercontent.com/$githubOwner/$githubRepo/refs/heads/main/app_config.json';
}
