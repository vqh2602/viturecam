import 'package:flutter_test/flutter_test.dart';
import 'package:viturecam/services/update_service.dart';

void main() {
  group('UpdateService semver comparison', () {
    test('detects newer minor version', () {
      expect(UpdateService.isNewerVersion('1.1.0', '1.0.3'), isTrue);
    });

    test('detects newer patch version', () {
      expect(UpdateService.isNewerVersion('1.0.5', '1.0.3'), isTrue);
    });

    test('detects newer major version', () {
      expect(UpdateService.isNewerVersion('2.0.0', '1.0.5'), isTrue);
    });

    test('handles tag with "v" prefix and build number', () {
      expect(UpdateService.isNewerVersion('v1.0.5', '1.0.3+4'), isTrue);
    });

    test('returns false when latest is older or equal', () {
      expect(UpdateService.isNewerVersion('1.0.3', '1.0.3'), isFalse);
      expect(UpdateService.isNewerVersion('1.0.2', '1.0.3'), isFalse);
      expect(UpdateService.isNewerVersion('v1.0.3', '1.0.3+4'), isFalse);
    });
  });

  group('AppReleaseInfo JSON deserialization', () {
    test('correctly parses GitHub release JSON and finds DMG asset', () {
      final mockJson = {
        'tag_name': 'v1.0.5',
        'name': 'Beauty Camera 1.0.5',
        'body': '## What\'s changed\n- Performance improvements',
        'published_at': '2026-09-15T07:41:24Z',
        'assets': [
          {
            'name': 'source.zip',
            'browser_download_url': 'https://github.com/vqh2602/viturecam/archive/v1.0.5.zip',
            'size': 123456
          },
          {
            'name': 'BeautyCamera-1.0.5.dmg',
            'browser_download_url': 'https://github.com/vqh2602/viturecam/releases/download/v1.0.5/BeautyCamera-1.0.5.dmg',
            'size': 30273366
          }
        ]
      };

      final release = AppReleaseInfo.fromJson(mockJson);

      expect(release.version, '1.0.5');
      expect(release.tagName, 'v1.0.5');
      expect(release.title, 'Beauty Camera 1.0.5');
      expect(release.body, contains('Performance improvements'));
      expect(release.dmgDownloadUrl, 'https://github.com/vqh2602/viturecam/releases/download/v1.0.5/BeautyCamera-1.0.5.dmg');
      expect(release.dmgSizeBytes, 30273366);
    });

    test('handles release without DMG asset gracefully', () {
      final mockJson = {
        'tag_name': 'v1.0.6',
        'name': 'Beauty Camera 1.0.6',
        'body': 'Bug fixes',
        'assets': [
          {
            'name': 'source.tar.gz',
            'browser_download_url': 'https://example.com/source.tar.gz',
            'size': 5000
          }
        ]
      };

      final release = AppReleaseInfo.fromJson(mockJson);
      expect(release.version, '1.0.6');
      expect(release.dmgDownloadUrl, isEmpty);
      expect(release.dmgSizeBytes, 0);
    });
  });
}
