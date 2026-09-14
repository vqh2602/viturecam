import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CameraDevice {
  final String id;
  final String name;
  final bool isDefault;

  const CameraDevice({
    required this.id,
    required this.name,
    required this.isDefault,
  });

  factory CameraDevice.fromMap(Map<dynamic, dynamic> map) {
    return CameraDevice(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Camera',
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }
}

class PerformanceStats {
  final double fps;
  final double renderTimeMs;
  final double trackingTimeMs;
  final double processingTimeMs;
  final int droppedFrames;
  final int width;
  final int height;

  const PerformanceStats({
    required this.fps,
    required this.renderTimeMs,
    this.trackingTimeMs = 0,
    this.processingTimeMs = 0,
    required this.droppedFrames,
    required this.width,
    required this.height,
  });

  factory PerformanceStats.fromMap(Map<dynamic, dynamic> map) {
    return PerformanceStats(
      fps: (map['fps'] as num?)?.toDouble() ?? 0.0,
      renderTimeMs: (map['renderTimeMs'] as num?)?.toDouble() ?? 0.0,
      trackingTimeMs: (map['trackingTimeMs'] as num?)?.toDouble() ?? 0.0,
      processingTimeMs: (map['processingTimeMs'] as num?)?.toDouble() ??
          (map['renderTimeMs'] as num?)?.toDouble() ?? 0.0,
      droppedFrames: (map['droppedFrames'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt() ?? 1920,
      height: (map['height'] as num?)?.toInt() ?? 1080,
    );
  }
}

class BeautyNativeApi {
  static const MethodChannel _channel = MethodChannel('com.beautycamera/native');

  Future<bool> initialize() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('initialize');
      return res?['success'] as bool? ?? true;
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] initialize error: $e');
      return false;
    }
  }

  Future<bool> requestCameraPermission() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('requestCameraPermission');
      return res?['granted'] as bool? ?? false;
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] requestCameraPermission error: $e');
      return false;
    }
  }

  Future<void> openCameraSettings() async {
    try {
      await _channel.invokeMethod('openCameraSettings');
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] openCameraSettings error: $e');
    }
  }

  Future<List<CameraDevice>> getCameras() async {
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getCameras');
      if (res == null) return [];
      return res.map((item) => CameraDevice.fromMap(item as Map<dynamic, dynamic>)).toList();
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] getCameras error: $e');
      return [];
    }
  }

  Future<int> startCamera({
    String? deviceId,
    int width = 1920,
    int height = 1080,
    int fps = 30,
  }) async {
    try {
      final Map<String, dynamic> args = {
        'width': width,
        'height': height,
        'fps': fps,
      };
      if (deviceId != null) {
        args['deviceId'] = deviceId;
      }
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('startCamera', args);
      return (res?['textureId'] as num?)?.toInt() ?? -1;
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] startCamera error: $e');
      rethrow;
    }
  }

  Future<void> stopCamera() async {
    try {
      await _channel.invokeMethod('stopCamera');
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] stopCamera error: $e');
    }
  }

  Future<void> setBeautySettings(Map<String, dynamic> settings) async {
    try {
      await _channel.invokeMethod('setBeautySettings', settings);
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] setBeautySettings error: $e');
    }
  }

  Future<void> setFaceSettings(Map<String, dynamic> settings) async {
    try {
      await _channel.invokeMethod('setFaceSettings', settings);
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] setFaceSettings error: $e');
    }
  }

  Future<void> setMakeupSettings(Map<String, dynamic> settings) async {
    try {
      await _channel.invokeMethod('setMakeupSettings', settings);
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] setMakeupSettings error: $e');
    }
  }

  Future<void> setFilter({required String filterId, required double intensity}) async {
    try {
      await _channel.invokeMethod('setFilter', {
        'filterId': filterId,
        'intensity': intensity,
      });
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] setFilter error: $e');
    }
  }

  Future<void> setColorSettings(Map<String, dynamic> settings) async {
    try {
      await _channel.invokeMethod('setColorSettings', settings);
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] setColorSettings error: $e');
    }
  }

  Future<void> setBackgroundSettings(Map<String, dynamic> settings) async {
    try {
      await _channel.invokeMethod('setBackgroundSettings', settings);
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] setBackgroundSettings error: $e');
    }
  }

  Future<void> enableBeauty(bool enabled) async {
    try {
      await _channel.invokeMethod('enableBeauty', {'enabled': enabled});
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] enableBeauty error: $e');
    }
  }

  Future<void> setCompareMode({required String mode, double splitRatio = 0.5}) async {
    try {
      await _channel.invokeMethod('setCompareMode', {
        'mode': mode,
        'splitRatio': splitRatio,
      });
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] setCompareMode error: $e');
    }
  }

  Future<bool> startVirtualCamera() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('startVirtualCamera');
      return res?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] startVirtualCamera error: $e');
      return false;
    }
  }

  Future<void> stopVirtualCamera() async {
    try {
      await _channel.invokeMethod('stopVirtualCamera');
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] stopVirtualCamera error: $e');
    }
  }

  Future<PerformanceStats> getPerformanceStats() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getPerformanceStats');
      if (res != null) {
        return PerformanceStats.fromMap(res);
      }
    } on PlatformException catch (e) {
      debugPrint('[BeautyNativeApi] getPerformanceStats error: $e');
    }
    return const PerformanceStats(fps: 0, renderTimeMs: 0, droppedFrames: 0, width: 1920, height: 1080);
  }
}
