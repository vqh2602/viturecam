import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppReleaseInfo {
  final String version;
  final String tagName;
  final String title;
  final String body;
  final String dmgDownloadUrl;
  final int dmgSizeBytes;
  final DateTime? publishedAt;

  const AppReleaseInfo({
    required this.version,
    required this.tagName,
    required this.title,
    required this.body,
    required this.dmgDownloadUrl,
    required this.dmgSizeBytes,
    this.publishedAt,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tagName = (json['tag_name'] as String? ?? '').trim();
    final cleanVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    final title = (json['name'] as String? ?? '').isNotEmpty
        ? json['name'] as String
        : 'Beauty Camera $cleanVersion';
    final body = json['body'] as String? ?? '';

    // Tìm asset .dmg
    final assets = json['assets'] as List<dynamic>? ?? [];
    String dmgUrl = '';
    int dmgSize = 0;

    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        final url = asset['browser_download_url'] as String? ?? '';
        if (name.endsWith('.dmg') && url.isNotEmpty) {
          dmgUrl = url;
          dmgSize = asset['size'] as int? ?? 0;
          break;
        }
      }
    }

    DateTime? publishedDate;
    if (json['published_at'] is String) {
      publishedDate = DateTime.tryParse(json['published_at'] as String);
    }

    return AppReleaseInfo(
      version: cleanVersion,
      tagName: tagName,
      title: title,
      body: body,
      dmgDownloadUrl: dmgUrl,
      dmgSizeBytes: dmgSize,
      publishedAt: publishedDate,
    );
  }
}

class UpdateService {
  static const MethodChannel _channel = MethodChannel('com.beautycamera/updater');
  static const String _repoUrl = 'https://api.github.com/repos/vqh2602/viturecam/releases/latest';

  /// So sánh hai chuỗi phiên bản dạng semver (ví dụ: '1.0.5' và '1.0.3')
  /// Trả về true nếu latest > current.
  static bool isNewerVersion(String latest, String current) {
    try {
      final cleanLatest = latest.split('+').first.replaceAll(RegExp(r'[^0-9.]'), '');
      final cleanCurrent = current.split('+').first.replaceAll(RegExp(r'[^0-9.]'), '');

      final latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;

      for (int i = 0; i < maxLength; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (e) {
      debugPrint('[UpdateService] Error comparing versions ($latest vs $current): $e');
      return false;
    }
  }

  /// Lấy thông tin phiên bản hiện tại từ macOS bundle
  Future<String> getCurrentVersion() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppInfo');
      if (result != null && result['version'] is String) {
        return result['version'] as String;
      }
    } catch (e) {
      debugPrint('[UpdateService] Failed to get app version from native channel: $e');
    }
    return '1.0.3';
  }

  /// Kiểm tra xem có phiên bản mới trên GitHub Release không
  Future<AppReleaseInfo?> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(Uri.parse(_repoUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github.v3+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'BeautyCamera-App');

      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('[UpdateService] GitHub API returned status code ${response.statusCode}');
        client.close();
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final release = AppReleaseInfo.fromJson(json);

      if (release.dmgDownloadUrl.isEmpty) {
        debugPrint('[UpdateService] Release ${release.version} has no DMG asset');
        return null;
      }

      if (isNewerVersion(release.version, currentVersion)) {
        debugPrint('[UpdateService] New update available: ${release.version} (current: $currentVersion)');
        return release;
      } else {
        debugPrint('[UpdateService] App is up to date: $currentVersion (latest: ${release.version})');
        return null;
      }
    } catch (e) {
      debugPrint('[UpdateService] Error checking for updates: $e');
      return null;
    }
  }

  /// Tải file .dmg từ GitHub Release với tiến trình
  Future<File> downloadDmg({
    required String downloadUrl,
    required String targetVersion,
    required void Function(int receivedBytes, int totalBytes) onProgress,
    bool Function()? isCancelled,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final targetFile = File('${tempDir.path}/BeautyCamera_${targetVersion}.dmg');

    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    final client = HttpClient();
    client.autoUncompress = false;

    try {
      // Xử lý chuyển hướng (redirect) của GitHub Releases sang AWS S3
      var currentUri = Uri.parse(downloadUrl);
      HttpClientResponse? response;
      int redirects = 0;

      while (redirects < 8) {
        final request = await client.getUrl(currentUri);
        request.followRedirects = false;
        request.headers.set(HttpHeaders.userAgentHeader, 'BeautyCamera-App');

        response = await request.close();

        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) {
            throw Exception('Redirect with no Location header');
          }
          currentUri = Uri.parse(location);
          redirects++;
        } else if (response.statusCode == 200) {
          break;
        } else {
          throw Exception('Failed to download DMG. HTTP Status: ${response.statusCode}');
        }
      }

      if (response == null || response.statusCode != 200) {
        throw Exception('Unable to reach download URL after redirects');
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      final sink = targetFile.openWrite();

      await for (final chunk in response) {
        if (isCancelled?.call() == true) {
          await sink.close();
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          throw Exception('Download cancelled by user');
        }

        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress(receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      client.close();

      return targetFile;
    } catch (e) {
      client.close();
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Gọi native macOS để cài đặt đè bản mới và khởi động lại
  Future<void> applyUpdate(String dmgPath) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('installUpdate', {
      'dmgPath': dmgPath,
    });

    if (result == null || result['success'] != true) {
      throw Exception('Native updater failed to trigger');
    }
  }
}
