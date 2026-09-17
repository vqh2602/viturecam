import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viturecam/features/camera/camera_controller.dart';
import 'package:viturecam/features/makeup/makeup_settings.dart';
import 'package:viturecam/features/patreon/patreon_models.dart';
import 'package:viturecam/features/patreon/patreon_provider.dart';
import 'package:viturecam/features/patreon/patreon_service.dart';
import 'package:viturecam/features/patreon/patreon_storage.dart';
import 'package:viturecam/platform/beauty_native_api.dart';

class FakeBeautyNativeApi extends BeautyNativeApi {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> requestCameraPermission() async => true;

  @override
  Future<List<CameraDevice>> getCameras() async => [];

  @override
  Future<int> startCamera({String? deviceId, int width = 1920, int height = 1080, int fps = 30}) async => 1;

  @override
  Future<void> stopCamera() async {}

  @override
  Future<void> setMakeupSettings(Map<String, dynamic> makeup) async {}

  @override
  Future<void> setBeautySettings(Map<String, dynamic> beauty) async {}

  @override
  Future<void> setFaceReshape(Map<String, dynamic> reshape) async {}

  @override
  Future<void> setFilter({required String filterId, double intensity = 1.0}) async {}

  @override
  Future<void> setColorAdjust(Map<String, dynamic> color) async {}

  @override
  Future<void> setBackgroundEffect(Map<String, dynamic> background) async {}

  @override
  Future<VirtualCameraStatus> getVirtualCameraStatus() async => const VirtualCameraStatus();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('patreon_test_');
    PatreonStorage.customDirectory = tempDir;
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
    PatreonStorage.customDirectory = null;
  });

  group('PatreonModels', () {
    test('PatreonAccount JSON serialization and getters', () {
      final account = PatreonAccount(
        id: '12345',
        fullName: 'Huy Vuong',
        email: 'huy@example.com',
        imageUrl: 'https://example.com/avatar.jpg',
        accessToken: 'access_token_abc',
        refreshToken: 'refresh_token_xyz',
        isPatron: true,
        patronStatus: 'active_patron',
        entitledAmountCents: 500,
        lastChecked: DateTime.parse('2026-12-31T00:00:00.000Z'),
        isTestMode: false,
      );

      final json = account.toJson();
      final restored = PatreonAccount.fromJson(json);

      expect(restored.id, '12345');
      expect(restored.fullName, 'Huy Vuong');
      expect(restored.email, 'huy@example.com');
      expect(restored.imageUrl, 'https://example.com/avatar.jpg');
      expect(restored.avatarUrl, 'https://example.com/avatar.jpg');
      expect(restored.accessToken, 'access_token_abc');
      expect(restored.refreshToken, 'refresh_token_xyz');
      expect(restored.isPatron, isTrue);
      expect(restored.patronStatus, 'active_patron');
      expect(restored.entitledAmountCents, 500);
      expect(restored.displayAmount, '\$5.00');
      expect(restored.isTestMode, isFalse);
    });

    test('PatreonConfig validation and serialization', () {
      const emptyConfig = PatreonConfig();
      expect(emptyConfig.isConfigured, isFalse);

      const customConfig = PatreonConfig(
        clientId: 'my_client_id',
        clientSecret: 'my_client_secret',
        redirectUri: 'http://localhost:8888/callback',
        campaignUrl: 'https://patreon.com/mycampaign',
      );

      expect(customConfig.isConfigured, isTrue);
      final json = customConfig.toJson();
      final restored = PatreonConfig.fromJson(json);

      expect(restored.clientId, 'my_client_id');
      expect(restored.clientSecret, 'my_client_secret');
      expect(restored.redirectUri, 'http://localhost:8888/callback');
      expect(restored.campaignUrl, 'https://patreon.com/mycampaign');
    });

    test('PatreonService createTestAccount produces valid VIP test account', () {
      final testAcc = PatreonService.createTestAccount(isPatron: true);
      expect(testAcc.isPatron, isTrue);
      expect(testAcc.isTestMode, isTrue);
      expect(testAcc.id, 'test_patron_id');
      expect(testAcc.patronStatus, 'active_patron');
      expect(testAcc.displayAmount, '\$5.00');
    });
  });

  group('PatreonService.parseIdentityResponse', () {
    test('parses active patron with active_patron status', () {
      final json = {
        'data': {
          'id': 'user_111',
          'attributes': {
            'full_name': 'Test Patron',
            'email': 'patron@example.com',
            'image_url': 'https://example.com/patron.png',
          },
        },
        'included': [
          {
            'type': 'member',
            'id': 'mem_222',
            'attributes': {
              'patron_status': 'active_patron',
              'currently_entitled_amount_cents': 1000,
              'last_charge_status': 'Paid',
            },
          },
        ]
      };

      final account = PatreonService.parseIdentityResponse(
        json: json,
        accessToken: 'mock_token',
        refreshToken: 'mock_refresh',
      );

      expect(account.id, 'user_111');
      expect(account.fullName, 'Test Patron');
      expect(account.email, 'patron@example.com');
      expect(account.imageUrl, 'https://example.com/patron.png');
      expect(account.avatarUrl, 'https://example.com/patron.png');
      expect(account.isPatron, isTrue);
      expect(account.patronStatus, 'active_patron');
      expect(account.entitledAmountCents, 1000);
      expect(account.displayAmount, '\$10.00');
    });

    test('identifies non-patron or former patron', () {
      final json = {
        'data': {
          'id': 'user_999',
          'attributes': {
            'full_name': 'Former Patron',
            'email': 'former@example.com',
          },
        },
        'included': [
          {
            'type': 'member',
            'id': 'mem_000',
            'attributes': {
              'patron_status': 'former_patron',
              'currently_entitled_amount_cents': 0,
              'last_charge_status': null,
            }
          }
        ]
      };

      final account = PatreonService.parseIdentityResponse(
        json: json,
        accessToken: 'mock_token',
      );

      expect(account.id, 'user_999');
      expect(account.fullName, 'Former Patron');
      expect(account.isPatron, isFalse);
      expect(account.patronStatus, 'former_patron');
      expect(account.entitledAmountCents, 0);
    });

    test('handles empty response gracefully', () {
      final json = <String, dynamic>{};
      final account = PatreonService.parseIdentityResponse(
        json: json,
        accessToken: 'empty_token',
      );

      expect(account.id, isEmpty);
      expect(account.fullName, 'Patreon User');
      expect(account.isPatron, isFalse);
    });
  });

  group('PatreonState and Gating in CameraController', () {
    test('PatreonState properties match account status', () {
      const unauthenticated = PatreonState();
      expect(unauthenticated.isLoggedIn, isFalse);
      expect(unauthenticated.isPatron, isFalse);

      final patronAccount = PatreonService.createTestAccount(isPatron: true);
      final activePatronState = PatreonState(account: patronAccount);
      expect(activePatronState.isLoggedIn, isTrue);
      expect(activePatronState.isPatron, isTrue);
      expect(activePatronState.isTestMode, isTrue);
    });

    test('CameraController blocks makeup when not patron', () async {
      final container = ProviderContainer(
        overrides: [
          beautyNativeApiProvider.overrideWithValue(FakeBeautyNativeApi()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);

      // Ban đầu patreonProvider chưa login -> isPatron == false
      expect(container.read(patreonProvider).isPatron, isFalse);

      // Thử apply makeup
      const testMakeup = MakeupSettings(
        lipPreset: 'red',
        lipOpacity: 70,
        blushPreset: 'peach',
        blushOpacity: 50,
      );

      controller.updateMakeup(testMakeup);

      // Vì chưa là patron, camera state makeup vẫn là const MakeupSettings() rỗng
      final currentMakeup = container.read(cameraControllerProvider).makeup;
      expect(currentMakeup.isModified, isFalse);
      expect(currentMakeup.lipPreset, 'none');
      expect(currentMakeup.blushPreset, 'none');
    });

    test('CameraController allows makeup when patron is active', () async {
      final container = ProviderContainer(
        overrides: [
          beautyNativeApiProvider.overrideWithValue(FakeBeautyNativeApi()),
        ],
      );
      addTearDown(container.dispose);

      // Bật test VIP mode
      await container.read(patreonProvider.notifier).enableTestMode(true);
      expect(container.read(patreonProvider).isPatron, isTrue);

      final controller = container.read(cameraControllerProvider.notifier);

      const testMakeup = MakeupSettings(
        lipPreset: 'red',
        lipOpacity: 70,
        blushPreset: 'peach',
        blushOpacity: 50,
      );

      controller.updateMakeup(testMakeup);

      // Vì đã là patron, camera state makeup được áp dụng thành công
      final currentMakeup = container.read(cameraControllerProvider).makeup;
      expect(currentMakeup.isModified, isTrue);
      expect(currentMakeup.lipPreset, 'red');
      expect(currentMakeup.lipOpacity, 70);
      expect(currentMakeup.blushPreset, 'peach');
      expect(currentMakeup.blushOpacity, 50);
    });

    test('CameraController resets makeup when patron expires or logs out', () async {
      final container = ProviderContainer(
        overrides: [
          beautyNativeApiProvider.overrideWithValue(FakeBeautyNativeApi()),
        ],
      );
      addTearDown(container.dispose);

      // Bật test VIP mode
      await container.read(patreonProvider.notifier).enableTestMode(true);
      expect(container.read(patreonProvider).isPatron, isTrue);

      final controller = container.read(cameraControllerProvider.notifier);

      const testMakeup = MakeupSettings(
        lipPreset: 'red',
        lipOpacity: 70,
      );

      controller.updateMakeup(testMakeup);
      expect(container.read(cameraControllerProvider).makeup.isModified, isTrue);

      // Giờ logout / tắt test mode
      await container.read(patreonProvider.notifier).enableTestMode(false);
      expect(container.read(patreonProvider).isPatron, isFalse);

      // Makeup phải tự động bị reset về mặc định
      final currentMakeup = container.read(cameraControllerProvider).makeup;
      expect(currentMakeup.isModified, isFalse);
      expect(currentMakeup.lipPreset, 'none');
    });
  });
}
