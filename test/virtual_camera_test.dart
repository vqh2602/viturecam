import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viturecam/platform/beauty_native_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.beautycamera/native');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final api = BeautyNativeApi();

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('installation and approval never report an active camera', () async {
    for (final state in ['installing', 'approval', 'connecting']) {
      messenger.setMockMethodCallHandler(channel, (_) async => {
        'state': state, 'active': false, 'message': 'Waiting for macOS',
      });
      final status = await api.startVirtualCamera();
      expect(status.active, isFalse);
      expect(status.pending, isTrue);
      expect(status.message, 'Waiting for macOS');
    }
  });

  test('legacy success flag cannot falsely turn the camera on', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => {'success': true});
    expect((await api.startVirtualCamera()).active, isFalse);
  });

  test('polling reflects activation and later stop', () async {
    var active = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getVirtualCameraStatus');
      return {'state': active ? 'active' : 'off', 'message': ''};
    });
    expect((await api.getVirtualCameraStatus()).active, isTrue);
    active = false;
    expect((await api.getVirtualCameraStatus()).active, isFalse);
  });

  test('installation failure preserves the reason for the user', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'activation_failed', message: 'Move app to Applications');
    });
    final status = await api.startVirtualCamera();
    expect(status.active, isFalse);
    expect(status.state, 'error');
    expect(status.message, 'Move app to Applications');
  });
}
