import '../background/background_settings.dart';
import '../beauty/beauty_settings.dart';
import '../color/color_settings.dart';
import '../makeup/makeup_settings.dart';
import '../reshape/reshape_settings.dart';

class PresetModel {
  final String id;
  final String name;
  final bool isBuiltIn;
  final BeautySettings beauty;
  final FaceSettings face;
  final MakeupSettings makeup;
  final String filterId;
  final double filterIntensity;
  final ColorSettings color;
  final BackgroundSettings background;

  const PresetModel({
    required this.id,
    required this.name,
    this.isBuiltIn = false,
    this.beauty = const BeautySettings(),
    this.face = const FaceSettings(),
    this.makeup = const MakeupSettings(),
    this.filterId = 'original',
    this.filterIntensity = 80,
    this.color = const ColorSettings(),
    this.background = const BackgroundSettings(),
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isBuiltIn': isBuiltIn,
      'beauty': beauty.toJson(),
      'face': face.toJson(),
      'makeup': makeup.toJson(),
      'filterId': filterId,
      'filterIntensity': filterIntensity,
      'color': color.toJson(),
      'background': background.toJson(),
    };
  }

  factory PresetModel.fromJson(Map<String, dynamic> json) {
    return PresetModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      beauty: json['beauty'] != null ? BeautySettings.fromJson(json['beauty'] as Map<String, dynamic>) : const BeautySettings(),
      face: json['face'] != null ? FaceSettings.fromJson(json['face'] as Map<String, dynamic>) : const FaceSettings(),
      makeup: json['makeup'] != null ? MakeupSettings.fromJson(json['makeup'] as Map<String, dynamic>) : const MakeupSettings(),
      filterId: json['filterId'] as String? ?? 'original',
      filterIntensity: (json['filterIntensity'] as num?)?.toDouble() ?? 80,
      color: json['color'] != null ? ColorSettings.fromJson(json['color'] as Map<String, dynamic>) : const ColorSettings(),
      background: json['background'] != null ? BackgroundSettings.fromJson(json['background'] as Map<String, dynamic>) : const BackgroundSettings(),
    );
  }

  static List<PresetModel> defaultPresets = [
    const PresetModel(
      id: 'natural',
      name: 'Natural',
      isBuiltIn: true,
      beauty: BeautySettings(smooth: 35, skinTexture: 60, skinBrightness: 20, whitening: 15),
      face: ReshapeSettings(slimFace: 20, eyeSize: 15, smile: 10),
      makeup: MakeupSettings(lipPreset: 'rose', lipOpacity: 35, blushPreset: 'rosy', blushOpacity: 30),
      filterId: 'clear',
      filterIntensity: 50,
      color: ColorSettings(brightness: 5, contrast: 5, saturation: 5),
    ),
    const PresetModel(
      id: 'soft',
      name: 'Soft',
      isBuiltIn: true,
      beauty: BeautySettings(smooth: 55, skinTexture: 40, whitening: 35, darkCircle: 40),
      face: ReshapeSettings(slimFace: 30, vFace: 20, eyeSize: 25),
      makeup: MakeupSettings(lipPreset: 'pink', lipOpacity: 45, blushPreset: 'peach', blushOpacity: 40),
      filterId: 'milk',
      filterIntensity: 65,
      color: ColorSettings(brightness: 10, highlights: 10, temperature: 5),
    ),
    const PresetModel(
      id: 'korean',
      name: 'Korean',
      isBuiltIn: true,
      beauty: BeautySettings(smooth: 60, whitening: 50, skinBrightness: 35, teethWhitening: 45),
      face: ReshapeSettings(slimFace: 45, vFace: 35, chinLength: -10, eyeSize: 35, noseWidth: -20),
      makeup: MakeupSettings(lipPreset: 'coral', lipOpacity: 60, blushPreset: 'coral', blushOpacity: 45, eyelinerPreset: 'cat', eyelinerOpacity: 40),
      filterId: 'clear',
      filterIntensity: 80,
      color: ColorSettings(brightness: 15, contrast: 10, saturation: 10),
    ),
    const PresetModel(
      id: 'clean',
      name: 'Clean',
      isBuiltIn: true,
      beauty: BeautySettings(smooth: 25, skinTexture: 70, redness: 40, teethWhitening: 30),
      face: ReshapeSettings(slimFace: 15, eyeSize: 10),
      makeup: MakeupSettings(lipPreset: 'nude', lipOpacity: 30),
      filterId: 'original',
      filterIntensity: 0,
      color: ColorSettings(sharpness: 20, contrast: 5),
    ),
    const PresetModel(
      id: 'live',
      name: 'Live Stream',
      isBuiltIn: true,
      beauty: BeautySettings(smooth: 65, whitening: 45, skinBrightness: 40, darkCircle: 60, eyeBag: 50, eyeWrinkle: 45, teethWhitening: 55),
      face: ReshapeSettings(slimFace: 40, vFace: 30, eyeSize: 35, eyeBrightness: 30, noseWidth: -25, smile: 15),
      makeup: MakeupSettings(lipPreset: 'red', lipOpacity: 55, blushPreset: 'rosy', blushOpacity: 50, eyelinerPreset: 'classic', eyelinerOpacity: 50),
      filterId: 'peach',
      filterIntensity: 75,
      color: ColorSettings(exposure: 10, brightness: 12, contrast: 15, saturation: 15),
    ),
    const PresetModel(
      id: 'camera_ready',
      name: 'Camera Ready',
      isBuiltIn: true,
      beauty: BeautySettings(smooth: 45, whitening: 30, skinBrightness: 25, darkCircle: 50, eyeWrinkle: 35, teethWhitening: 40),
      face: ReshapeSettings(slimFace: 30, vFace: 25, cheekWidth: -15, eyeSize: 20, noseBridge: 15),
      makeup: MakeupSettings(lipPreset: 'berry', lipOpacity: 45, blushPreset: 'mauve', blushOpacity: 35),
      filterId: 'film',
      filterIntensity: 60,
      color: ColorSettings(brightness: 8, contrast: 12, saturation: 8, sharpness: 15),
    ),
  ];
}
