import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String? downloadUrl;
  final String? releaseNotes;
  final String releaseName;
  final DateTime? publishedAt;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    this.downloadUrl,
    this.releaseNotes,
    required this.releaseName,
    this.publishedAt,
  });
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String currentAppVersion = '1.0.14';
  static const String repoOwner = 'bhaijew';
  static const String repoName = 'appsolewhat';
  static const String releasesUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Compare two semantic version strings (e.g. "1.0.12" vs "1.0.13" or "v1.0.13")
  bool _isNewerVersion(String latest, String current) {
    final cleanLatest = latest.replaceAll(RegExp(r'[^0-9.]'), '');
    final cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '');

    final latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Check GitHub Releases for the latest APK
  Future<UpdateInfo> checkForUpdate() async {
    try {
      final res = await http.get(
        Uri.parse(releasesUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'SoleWhat-Admin-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final tagName = data['tag_name']?.toString() ?? '';
        final releaseName = data['name']?.toString() ?? tagName;
        final body = data['body']?.toString() ?? '';
        final publishedStr = data['published_at']?.toString();
        final publishedAt = publishedStr != null ? DateTime.tryParse(publishedStr) : null;

        // Find APK asset
        String? apkUrl;
        if (data['assets'] is List) {
          for (final asset in data['assets']) {
            final name = asset['name']?.toString().toLowerCase() ?? '';
            if (name.endsWith('.apk')) {
              apkUrl = asset['browser_download_url']?.toString();
              break;
            }
          }
        }

        // Fallback to release HTML url if no direct APK asset
        apkUrl ??= data['html_url']?.toString();

        final hasNewer = _isNewerVersion(tagName, currentAppVersion);

        return UpdateInfo(
          currentVersion: currentAppVersion,
          latestVersion: tagName.replaceAll('v', ''),
          hasUpdate: hasNewer,
          downloadUrl: apkUrl,
          releaseNotes: body,
          releaseName: releaseName,
          publishedAt: publishedAt,
        );
      }
    } catch (_) {}

    return UpdateInfo(
      currentVersion: currentAppVersion,
      latestVersion: currentAppVersion,
      hasUpdate: false,
      releaseName: 'v$currentAppVersion',
    );
  }

  /// Open browser or direct download for APK
  Future<bool> launchDownload(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
