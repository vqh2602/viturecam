import 'package:flutter_test/flutter_test.dart';
import 'package:viturecam/features/background/background_settings.dart';
import 'package:viturecam/features/beauty/beauty_settings.dart';
import 'package:viturecam/features/color/color_settings.dart';
import 'package:viturecam/features/filters/filter_model.dart';
import 'package:viturecam/features/makeup/makeup_settings.dart';
import 'package:viturecam/features/presets/preset_model.dart';
import 'package:viturecam/features/reshape/reshape_settings.dart';

void main() {
  group('BeautySettings', () {
    test('defaults and modification detection', () {
      const settings = BeautySettings();
      expect(settings.smooth, 0);
      expect(settings.skinTexture, 50);
      expect(settings.skinTone, 0);
      expect(settings.skinToneType, 'natural');
      expect(settings.isModified, false);

      final modified = settings.copyWith(smooth: 45, skinTone: 60, skinToneType: 'porcelain');
      expect(modified.smooth, 45);
      expect(modified.skinTone, 60);
      expect(modified.skinToneType, 'porcelain');
      expect(modified.isModified, true);
      expect(modified.isKeyActive('smooth'), true);
      expect(modified.isKeyActive('skinTone'), true);
      expect(modified.isKeyActive('whitening'), false);
    });

    test('normalization toMap', () {
      const settings = BeautySettings(smooth: 50, whitening: 80, skinTone: 70, skinToneType: 'peach');
      final map = settings.toMap();
      expect(map['smooth'], 0.5);
      expect(map['whitening'], 0.8);
      expect(map['skinTone'], 0.7);
      expect(map['skinToneType'], 'peach');
    });

    test('json roundtrip', () {
      const settings = BeautySettings(smooth: 30, teethWhitening: 60, skinTone: 55, skinToneType: 'rosy');
      final json = settings.toJson();
      final restored = BeautySettings.fromJson(json);
      expect(restored.smooth, 30);
      expect(restored.teethWhitening, 60);
      expect(restored.skinTone, 55);
      expect(restored.skinToneType, 'rosy');
    });
  });

  group('ReshapeSettings', () {
    test('defaults and normalization', () {
      const settings = ReshapeSettings();
      expect(settings.smileCorners, 0);
      expect(settings.eyebrowHeight, 0);
      expect(settings.eyebrowArch, 0);
      expect(settings.eyebrowTilt, 0);
      expect(settings.hairline, 0);
      expect(settings.templeWidth, 0);
      expect(settings.cheekWidth, 0);
      expect(settings.eyeBrightness, 0);
      expect(settings.eyeSparkle, 0);
      expect(settings.eyeSparkleStyle, 'starlight');
      expect(settings.isModified, false);

      final modified = settings.copyWith(
        slimFace: 40,
        jawWidth: -25,
        cheekWidth: -30,
        templeWidth: 20,
        hairline: -40,
        eyeBrightness: 60,
        eyeSparkle: 75,
        eyeSparkleStyle: 'crystal',
        smileCorners: 60,
        eyebrowHeight: 25,
        eyebrowArch: 30,
        eyebrowTilt: -35,
      );
      expect(modified.isModified, true);
      expect(modified.isKeyActive('slimFace'), true);
      expect(modified.isKeyActive('jawWidth'), true);
      expect(modified.isKeyActive('cheekWidth'), true);
      expect(modified.isKeyActive('templeWidth'), true);
      expect(modified.isKeyActive('hairline'), true);
      expect(modified.isKeyActive('eyeBrightness'), true);
      expect(modified.isKeyActive('eyeSparkle'), true);
      expect(modified.isKeyActive('smileCorners'), true);
      expect(modified.isKeyActive('eyebrowHeight'), true);
      expect(modified.isKeyActive('eyebrowArch'), true);
      expect(modified.isKeyActive('eyebrowTilt'), true);

      final map = modified.toMap();
      expect(map['slimFace'], 0.4);
      expect(map['jawWidth'], -0.5);
      expect(map['cheekWidth'], -0.6);
      expect(map['templeWidth'], 0.4);
      expect(map['hairline'], -0.8);
      expect(map['eyeBrightness'], 0.6);
      expect(map['eyeSparkle'], 0.75);
      expect(map['eyeSparkleStyle'], 'crystal');
      expect(map['smileCorners'], 0.6);
      expect(map['eyebrowHeight'], 0.5);
      expect(map['eyebrowArch'], 0.6);
      expect(map['eyebrowTilt'], -0.7);
    });

    test('json roundtrip with smileCorners, eyebrows, hairline, and eye sparkle', () {
      const settings = ReshapeSettings(
        smile: 30,
        smileCorners: 75,
        eyebrowHeight: 35,
        eyebrowArch: 15,
        eyebrowTilt: -20,
        templeWidth: 25,
        cheekWidth: -15,
        hairline: 45,
        eyeBrightness: 50,
        eyeSparkle: 80,
        eyeSparkleStyle: 'ring',
      );
      final json = settings.toJson();
      final restored = ReshapeSettings.fromJson(json);
      expect(restored.smile, 30);
      expect(restored.smileCorners, 75);
      expect(restored.eyebrowHeight, 35);
      expect(restored.eyebrowArch, 15);
      expect(restored.eyebrowTilt, -20);
      expect(restored.templeWidth, 25);
      expect(restored.cheekWidth, -15);
      expect(restored.hairline, 45);
      expect(restored.eyeBrightness, 50);
      expect(restored.eyeSparkle, 80);
      expect(restored.eyeSparkleStyle, 'ring');
    });
  });

  group('MakeupSettings', () {
    test('lipstick options and opacity', () {
      const settings = MakeupSettings(
        lipPreset: 'rose',
        lipOpacity: 70,
        lipStyle: 'gloss',
        blushStyle: 'sunkissed',
        eyebrowStyle: 'korean',
        eyelinerStyle: 'fox',
        eyeshadowStyle: 'douyin',
      );
      expect(settings.isModified, true);
      expect(settings.isKeyActive('lip'), true);
      expect(settings.isKeyActive('blush'), false);
      expect(settings.lipStyle, 'gloss');
      expect(settings.blushStyle, 'sunkissed');
      expect(settings.eyebrowStyle, 'korean');
      expect(settings.eyelinerStyle, 'fox');
      expect(settings.eyeshadowStyle, 'douyin');

      final map = settings.toMap();
      expect(map['lipPreset'], 'rose');
      expect(map['lipOpacity'], 0.7);
      expect(map['lipStyle'], 'gloss');
      expect(map['blushStyle'], 'sunkissed');
      expect(map['eyebrowStyle'], 'korean');
      expect(map['eyelinerStyle'], 'fox');
      expect(map['eyeshadowStyle'], 'douyin');

      final json = settings.toJson();
      final restored = MakeupSettings.fromJson(json);
      expect(restored.lipStyle, 'gloss');
      expect(restored.blushStyle, 'sunkissed');
      expect(restored.eyebrowStyle, 'korean');
      expect(restored.eyelinerStyle, 'fox');
      expect(restored.eyeshadowStyle, 'douyin');
    });

    test('eyebrow styles support both female and male classifications', () {
      final femaleStyles = MakeupPresets.femaleEyebrowStyles.map((e) => e.id).toList();
      expect(femaleStyles, contains('natural'));
      expect(femaleStyles, contains('korean'));
      expect(femaleStyles, contains('arched'));
      expect(femaleStyles, contains('willow'));
      expect(femaleStyles, contains('feathered'));

      final maleStyles = MakeupPresets.maleEyebrowStyles.map((e) => e.id).toList();
      expect(maleStyles, contains('male_natural'));
      expect(maleStyles, contains('male_sword'));
      expect(maleStyles, contains('male_bold'));
      expect(maleStyles, contains('male_feathered'));

      expect(MakeupPresets.isMaleEyebrow('male_natural'), true);
      expect(MakeupPresets.isMaleEyebrow('male_sword'), true);
      expect(MakeupPresets.isMaleEyebrow('male_bold'), true);
      expect(MakeupPresets.isMaleEyebrow('male_feathered'), true);
      expect(MakeupPresets.isMaleEyebrow('natural'), false);
      expect(MakeupPresets.isMaleEyebrow('korean'), false);

      const maleSettings = MakeupSettings(
        eyebrowPreset: 'charcoal',
        eyebrowOpacity: 85,
        eyebrowStyle: 'male_sword',
      );
      expect(maleSettings.toMap()['eyebrowStyle'], 'male_sword');
      final restoredMale = MakeupSettings.fromJson(maleSettings.toJson());
      expect(restoredMale.eyebrowStyle, 'male_sword');
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

      for (final mode in ['strong_blur', 'virtual_studio', 'zoom_blur', 'swirly_bokeh', 'dreamy_blur', 'motion_blur']) {
        final s = settings.copyWith(mode: mode);
        expect(s.mode, mode);
        expect(s.isKeyActive(mode), true);
        expect(s.toMap()['mode'], mode);
      }
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

  group('FilterCatalog', () {
    test('contains rich presets with categories', () {
      expect(FilterCatalog.presets.length, greaterThanOrEqualTo(25));
      final categories = FilterCatalog.presets.map((p) => p.category).toSet();
      expect(categories.contains('Douyin'), true);
      expect(categories.contains('Natural'), true);
      expect(categories.contains('Korean'), true);
      expect(categories.contains('Film'), true);
      expect(categories.contains('Warm'), true);
      expect(categories.contains('Cool'), true);
      expect(categories.contains('B&W'), true);
    });
  });
}
