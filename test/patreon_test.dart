import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viturecam/features/beauty/beauty_settings.dart';
import 'package:viturecam/features/camera/camera_controller.dart';
import 'package:viturecam/features/makeup/makeup_settings.dart';
import 'package:viturecam/features/patreon/patreon_models.dart';
import 'package:viturecam/features/patreon/patreon_provider.dart';
import 'package:viturecam/features/patreon/patreon_service.dart';
import 'package:viturecam/features/patreon/patreon_storage.dart';
import 'package:viturecam/features/presets/preset_model.dart';
import 'package:viturecam/features/reshape/reshape_settings.dart';
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
  Future<void> setFaceSettings(Map<String, dynamic> face) async {}

  @override
  Future<void> setFilter({required String filterId, required double intensity}) async {}

  @override
  Future<void> setColorSettings(Map<String, dynamic> color) async {}

  @override
  Future<void> setBackgroundSettings(Map<String, dynamic> background) async {}

  @override
  Future<void> enableBeauty(bool enabled) async {}

  @override
  Future<void> setCompareMode({required String mode, double splitRatio = 0.5}) async {}

  @override
  Future<VirtualCameraStatus> getVirtualCameraStatus() async => const VirtualCameraStatus();
}

class MockPatreonService extends PatreonService {
  @override
  Future<PatreonAccount> fetchIdentity({
    required String accessToken,
    String? refreshToken,
    String targetCampaignId = PatreonConfig.defaultCampaignId,
  }) async {
    return const PatreonAccount(
      id: '224342455',
      fullName: 'Huy Vương',
      email: 'vqh2602@gmail.com',
      isPatron: true,
      isCreator: true,
      patronStatus: 'creator',
      accessToken: 'creator_token',
    );
  }
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

    test('PatreonConfig default values for campaign 16838541', () {
      const config = PatreonConfig();
      expect(config.campaignUrl, 'https://www.patreon.com/16838541/join');
      expect(config.campaignId, '16838541');
      expect(config.creatorName, 'Huy Vương');
      expect(config.clientId, PatreonConfig.defaultClientId);
      expect(config.clientSecret, PatreonConfig.defaultClientSecret);
      expect(config.isConfigured, isTrue);
      expect(config.hasCreatorToken, isTrue);
    });

    test('PatreonConfig validation and serialization', () {
      const emptyConfig = PatreonConfig(clientId: '', clientSecret: '', creatorAccessToken: '');
      expect(emptyConfig.isConfigured, isFalse);
      expect(emptyConfig.hasCreatorToken, isFalse);

      const customConfig = PatreonConfig(
        clientId: 'my_client_id',
        clientSecret: 'my_client_secret',
        redirectUri: 'http://localhost:8888/callback',
        campaignUrl: 'https://patreon.com/mycampaign',
        campaignId: '987654',
      );

      expect(customConfig.isConfigured, isTrue);
      final json = customConfig.toJson();
      final restored = PatreonConfig.fromJson(json);

      expect(restored.clientId, 'my_client_id');
      expect(restored.clientSecret, 'my_client_secret');
      expect(restored.redirectUri, 'http://localhost:8888/callback');
      expect(restored.campaignUrl, 'https://patreon.com/mycampaign');
      expect(restored.campaignId, '987654');
    });

    test('PatreonAccount displayAmount reflects Creator VIP', () {
      const creatorAccount = PatreonAccount(
        id: 'creator_1',
        fullName: 'Huy Vương',
        email: 'huyvq.bachkhoa@gmail.com',
        isPatron: true,
        isCreator: true,
        accessToken: 'tok',
      );
      expect(creatorAccount.displayAmount, 'Creator VIP');
      expect(creatorAccount.isCreator, isTrue);
      expect(creatorAccount.isPatron, isTrue);
    });

    test('PatreonService createTestAccount produces valid VIP test account', () {
      final testAcc = PatreonService.createTestAccount(isPatron: true);
      expect(testAcc.isPatron, isTrue);
      expect(testAcc.isTestMode, isTrue);
      expect(testAcc.id, 'test_patron_id');
      expect(testAcc.patronStatus, 'active_patron');
      expect(testAcc.campaignId, '16838541');
      expect(testAcc.displayAmount, 'Creator VIP');
    });
  });

  group('PatreonService.parseIdentityResponse', () {
    test('recognizes creator by campaign relationship as VIP', () {
      final json = {
        'data': {
          'id': 'creator_user_id',
          'attributes': {
            'full_name': 'Huy Vương',
            'email': 'creator@example.com',
          },
          'relationships': {
            'campaign': {
              'data': {
                'id': '16838541',
                'type': 'campaign',
              }
            }
          }
        },
        'included': []
      };

      final account = PatreonService.parseIdentityResponse(
        json: json,
        accessToken: 'mock_token',
        targetCampaignId: '16838541',
      );

      expect(account.isCreator, isTrue);
      expect(account.isPatron, isTrue);
      expect(account.patronStatus, 'creator');
      expect(account.displayAmount, 'Creator VIP');
    });

    test('recognizes creator by creator email as VIP', () {
      final json = {
        'data': {
          'id': 'user_huy',
          'attributes': {
            'full_name': 'Huy Vương',
            'email': 'huyvq.bachkhoa@gmail.com',
          },
        },
        'included': []
      };

      final account = PatreonService.parseIdentityResponse(
        json: json,
        accessToken: 'mock_token',
        targetCampaignId: '16838541',
      );

      expect(account.isCreator, isTrue);
      expect(account.isPatron, isTrue);
      expect(account.displayAmount, 'Creator VIP');
    });

    test('recognizes creator by vqh2602@gmail.com and user id 224342455 as VIP', () {
      final json = {
        'data': {
          'id': '224342455',
          'attributes': {
            'full_name': 'Huy Vương',
            'email': 'vqh2602@gmail.com',
            'url': 'https://www.patreon.com/HuyVuong',
          },
        },
        'included': []
      };

      final account = PatreonService.parseIdentityResponse(
        json: json,
        accessToken: 'mock_token',
        targetCampaignId: '16838541',
      );

      expect(account.isCreator, isTrue);
      expect(account.isPatron, isTrue);
      expect(account.patronStatus, 'creator');
      expect(account.displayAmount, 'Creator VIP');
    });

    test('parses active patron belonging to campaign 16838541', () {
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
              'currently_entitled_amount_cents': 300,
              'last_charge_status': 'Paid',
            },
            'relationships': {
              'campaign': {
                'data': {
                  'id': '16838541',
                  'type': 'campaign',
                }
              }
            }
          },
        ]
      };

      final account = PatreonService.parseIdentityResponse(
        json: json,
        accessToken: 'mock_token',
        refreshToken: 'mock_refresh',
        targetCampaignId: '16838541',
      );

      expect(account.id, 'user_111');
      expect(account.fullName, 'Test Patron');
      expect(account.email, 'patron@example.com');
      expect(account.imageUrl, 'https://example.com/patron.png');
      expect(account.avatarUrl, 'https://example.com/patron.png');
      expect(account.isPatron, isTrue);
      expect(account.isCreator, isFalse);
      expect(account.patronStatus, 'active_patron');
      expect(account.entitledAmountCents, 300);
      expect(account.displayAmount, '\$3.00');
    });

    test('ignores member pledge belonging to a different campaign', () {
      final json = {
        'data': {
          'id': 'user_different',
          'attributes': {
            'full_name': 'Other Supporter',
            'email': 'other@example.com',
          },
        },
        'included': [
          {
            'type': 'member',
            'id': 'mem_diff',
            'attributes': {
              'patron_status': 'active_patron',
              'currently_entitled_amount_cents': 1000,
              'last_charge_status': 'Paid',
            },
            'relationships': {
              'campaign': {
                'data': {
                  'id': '99999999', // Different campaign!
                  'type': 'campaign',
                }
              }
            }
          },
        ]
      };

      final account = PatreonService.parseIdentityResponse(
        json: json,
        accessToken: 'mock_token',
        targetCampaignId: '16838541',
      );

      // Pledged to a different creator, NOT to Huy Vương (16838541)
      expect(account.isPatron, isFalse);
      expect(account.entitledAmountCents, 0);
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
            },
            'relationships': {
              'campaign': {
                'data': {
                  'id': '16838541',
                  'type': 'campaign',
                }
              }
            }
          }
        ]
      };

      final account = PatreonService.parseIdentityResponse(
        json: json,
        accessToken: 'mock_token',
        targetCampaignId: '16838541',
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

    test('loginWithCreatorToken fetches and saves Creator VIP account', () async {
      final notifier = PatreonNotifier(MockPatreonService());
      addTearDown(notifier.dispose);

      final success = await notifier.loginWithCreatorToken();
      expect(success, isTrue);
      expect(notifier.state.isCreator, isTrue);
      expect(notifier.state.isPatron, isTrue);
      expect(notifier.state.fullName, 'Huy Vương');
      expect(notifier.state.displayAmount, 'Creator VIP');
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
          patreonProvider.overrideWith((ref) => PatreonNotifier(MockPatreonService())),
        ],
      );
      addTearDown(container.dispose);

      // Đăng nhập creator VIP
      await container.read(patreonProvider.notifier).loginWithCreatorToken();
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
          patreonProvider.overrideWith((ref) => PatreonNotifier(MockPatreonService())),
        ],
      );
      addTearDown(container.dispose);

      // Đăng nhập creator VIP
      await container.read(patreonProvider.notifier).loginWithCreatorToken();
      expect(container.read(patreonProvider).isPatron, isTrue);

      final controller = container.read(cameraControllerProvider.notifier);

      const testMakeup = MakeupSettings(
        lipPreset: 'red',
        lipOpacity: 70,
      );

      controller.updateMakeup(testMakeup);
      expect(container.read(cameraControllerProvider).makeup.isModified, isTrue);

      // Giờ logout
      await container.read(patreonProvider.notifier).logout();
      expect(container.read(patreonProvider).isPatron, isFalse);

      // Makeup phải tự động bị reset về mặc định
      final currentMakeup = container.read(cameraControllerProvider).makeup;
      expect(currentMakeup.isModified, isFalse);
      expect(currentMakeup.lipPreset, 'none');
    });

    test('CameraController gates jawWidth, skinBrightness, whitening, and Douyin filters for non-patrons', () async {
      final container = ProviderContainer(
        overrides: [
          beautyNativeApiProvider.overrideWithValue(FakeBeautyNativeApi()),
          patreonProvider.overrideWith((ref) => PatreonNotifier(MockPatreonService())),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(patreonProvider).isPatron, isFalse);
      final controller = container.read(cameraControllerProvider.notifier);

      // 1. Jaw width (Hàm) gating
      controller.updateFace(const ReshapeSettings(jawWidth: 35, slimFace: 20));
      var currentFace = container.read(cameraControllerProvider).face;
      expect(currentFace.jawWidth, 0); // Blocked
      expect(currentFace.slimFace, 20); // Non-VIP allowed

      // 2. Brighten & Whitening (Làm sáng & Trắng da) gating
      controller.updateBeauty(const BeautySettings(smooth: 40, skinBrightness: 30, whitening: 25));
      var currentBeauty = container.read(cameraControllerProvider).beauty;
      expect(currentBeauty.smooth, 40); // Non-VIP allowed
      expect(currentBeauty.skinBrightness, 0); // Blocked
      expect(currentBeauty.whitening, 0); // Blocked

      // 3. Douyin filter gating
      controller.updateFilter('douyin_fairy', 85);
      var currentState = container.read(cameraControllerProvider);
      expect(currentState.filterId, 'original'); // Douyin blocked for non-patrons

      // 4. Non-Douyin filter should be allowed
      controller.updateFilter('clear', 75);
      currentState = container.read(cameraControllerProvider);
      expect(currentState.filterId, 'clear');
      expect(currentState.filterIntensity, 75);
    });

    test('CameraController allows all VIP features when patron is active', () async {
      final container = ProviderContainer(
        overrides: [
          beautyNativeApiProvider.overrideWithValue(FakeBeautyNativeApi()),
          patreonProvider.overrideWith((ref) => PatreonNotifier(MockPatreonService())),
        ],
      );
      addTearDown(container.dispose);

      await container.read(patreonProvider.notifier).loginWithCreatorToken();
      expect(container.read(patreonProvider).isPatron, isTrue);
      final controller = container.read(cameraControllerProvider.notifier);

      // 1. Jaw width
      controller.updateFace(const ReshapeSettings(jawWidth: 35));
      expect(container.read(cameraControllerProvider).face.jawWidth, 35);

      // 2. Brighten & Whitening
      controller.updateBeauty(const BeautySettings(skinBrightness: 30, whitening: 25));
      expect(container.read(cameraControllerProvider).beauty.skinBrightness, 30);
      expect(container.read(cameraControllerProvider).beauty.whitening, 25);

      // 3. Douyin filter
      controller.updateFilter('douyin_fairy', 85);
      expect(container.read(cameraControllerProvider).filterId, 'douyin_fairy');
      expect(container.read(cameraControllerProvider).filterIntensity, 85);
    });

    test('CameraController resets all VIP features on logout or expiration', () async {
      final container = ProviderContainer(
        overrides: [
          beautyNativeApiProvider.overrideWithValue(FakeBeautyNativeApi()),
          patreonProvider.overrideWith((ref) => PatreonNotifier(MockPatreonService())),
        ],
      );
      addTearDown(container.dispose);

      await container.read(patreonProvider.notifier).loginWithCreatorToken();
      final controller = container.read(cameraControllerProvider.notifier);

      // Apply VIP features
      controller.updateFace(const ReshapeSettings(jawWidth: 30, slimFace: 20));
      controller.updateBeauty(const BeautySettings(smooth: 40, skinBrightness: 35, whitening: 20));
      controller.updateFilter('douyin_fairy', 85);

      expect(container.read(cameraControllerProvider).face.jawWidth, 30);
      expect(container.read(cameraControllerProvider).beauty.skinBrightness, 35);
      expect(container.read(cameraControllerProvider).beauty.whitening, 20);
      expect(container.read(cameraControllerProvider).filterId, 'douyin_fairy');

      // Logout
      await container.read(patreonProvider.notifier).logout();
      expect(container.read(patreonProvider).isPatron, isFalse);

      // Verify all VIP features reset, non-VIP features preserved
      final state = container.read(cameraControllerProvider);
      expect(state.face.jawWidth, 0);
      expect(state.face.slimFace, 20);
      expect(state.beauty.skinBrightness, 0);
      expect(state.beauty.whitening, 0);
      expect(state.beauty.smooth, 40);
      expect(state.filterId, 'original');
    });

    test('PresetModel application sanitizes VIP features for non-patrons', () async {
      final container = ProviderContainer(
        overrides: [
          beautyNativeApiProvider.overrideWithValue(FakeBeautyNativeApi()),
          patreonProvider.overrideWith((ref) => PatreonNotifier(MockPatreonService())),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(patreonProvider).isPatron, isFalse);
      final controller = container.read(cameraControllerProvider.notifier);

      const vipPreset = PresetModel(
        id: 'test_vip_preset',
        name: 'VIP Preset',
        beauty: BeautySettings(smooth: 50, skinBrightness: 40, whitening: 30),
        face: ReshapeSettings(slimFace: 30, jawWidth: 25),
        makeup: MakeupSettings(lipPreset: 'red', lipOpacity: 80),
        filterId: 'douyin_sweet',
        filterIntensity: 85,
      );

      await controller.applyPreset(vipPreset);

      final state = container.read(cameraControllerProvider);
      // Non-VIP allowed
      expect(state.beauty.smooth, 50);
      expect(state.face.slimFace, 30);
      // VIP sanitized
      expect(state.beauty.skinBrightness, 0);
      expect(state.beauty.whitening, 0);
      expect(state.face.jawWidth, 0);
      expect(state.makeup.isModified, isFalse);
      expect(state.filterId, 'original');
      expect(state.filterIntensity, 0.0);
    });
  });
}
