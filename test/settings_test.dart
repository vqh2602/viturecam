import 'package:flutter_test/flutter_test.dart';
import 'package:viturecam/features/background/background_settings.dart';
import 'package:viturecam/features/beauty/beauty_settings.dart';
import 'package:viturecam/features/color/color_settings.dart';
import 'package:viturecam/features/makeup/makeup_settings.dart';
import 'package:viturecam/features/presets/preset_model.dart';
import 'package:viturecam/features/reshape/reshape_settings.dart';

void main() {
  group('BeautySettings', () {
    test('defaults and modification detection', () {
      const settings = BeautySettings();
      expect(settings.smooth, 0);
      expect(settings.skinTexture, 50);
      expect(settings.isModified, false);

      final modified = settings.copyWith(smooth: 45);
      expect(modified.smooth, 45);
      expect(modified.isModified, true);
      expect(modified.isKeyActive('smooth'), true);
      expect(modified.isKeyActive('whitening'), false);
    });

    test('normalization toMap', () {
      const settings = BeautySettings(smooth: 50, whitening: 80);
      final map = settings.toMap();
      expect(map['smooth'], 0.5);
      expect(map['whitening'], 0.8);
    });

    test('json roundtrip', () {
      const settings = BeautySettings(smooth: 30, teethWhitening: 60);
      final json = settings.toJson();
      final restored = BeautySettings.fromJson(json);
      expect(restored.smooth, 30);
      expect(restored.teethWhitening, 60);
    });
  });

  group('ReshapeSettings', () {
    test('defaults and normalization', () {
      const settings = ReshapeSettings();
      expect(settings.isModified, false);

      final modified = settings.copyWith(slimFace: 40, jawWidth: -25);
      expect(modified.isModified, true);
      expect(modified.isKeyActive('slimFace'), true);
      expect(modified.isKeyActive('jawWidth'), true);

      final map = modified.toMap();
      expect(map['slimFace'], 0.4);
      expect(map['jawWidth'], -0.5);
    });
  });

  group('MakeupSettings', () {
    test('lipstick options and opacity', () {
      const settings = MakeupSettings(lipPreset: 'rose', lipOpacity: 70);
      expect(settings.isModified, true);
      expect(settings.isKeyActive('lip'), true);
      expect(settings.isKeyActive('blush'), false);

      final map = settings.toMap();
      expect(map['lipPreset'], 'rose');
      expect(map['lipOpacity'], 0.7);
    });
  });

  group('ColorSettings', () {
    test('defaults and mapping', () {
      const settings = ColorSettings(brightness: 20, contrast: 10, saturation: 15);
      expect(settings.isModified, true);
      final map = settings.toMap();
      expect(map['brightness'], 0.2);
      expect(map['contrast'], 1.05);
      expect(map['saturation'], 1.15);
    });
  });

  group('BackgroundSettings', () {
    test('modes and blur mapping', () {
      const settings = BackgroundSettings(mode: 'portrait_blur', blurIntensity: 75);
      expect(settings.isModified, true);
      expect(settings.isKeyActive('portrait_blur'), true);
      expect(settings.isKeyActive('none'), false);
      expect(settings.toMap()['blurIntensity'], 0.75);
    });
  });

  group('PresetModel', () {
    test('default presets exist and can be serialized', () {
      expect(PresetModel.defaultPresets.length, greaterThanOrEqualTo(6));
      final natural = PresetModel.defaultPresets.first;
      expect(natural.name, 'Natural');

      final json = natural.toJson();
      final restored = PresetModel.fromJson(json);
      expect(restored.name, natural.name);
      expect(restored.beauty.smooth, natural.beauty.smooth);
      expect(restored.filterId, natural.filterId);
    });
  });
}
