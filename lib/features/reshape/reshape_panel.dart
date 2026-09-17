import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/beauty_slider.dart';
import '../../widgets/tool_button.dart';
import '../camera/camera_controller.dart';

class ReshapePanel extends ConsumerWidget {
  const ReshapePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final f = state.face;
    final b = state.beauty;
    final subTool = state.activeSubTool;

    final faceTools = [
      {'id': 'slimFace', 'label': l10n.reshapeSlimFace, 'icon': Icons.face_retouching_natural},
      {'id': 'smallFace', 'label': l10n.reshapeSmallFace, 'icon': Icons.compress},
      {'id': 'vFace', 'label': l10n.reshapeVFace, 'icon': Icons.arrow_downward},
      {'id': 'jawWidth', 'label': l10n.reshapeJaw, 'icon': Icons.swap_horiz},
      {'id': 'jawline', 'label': l10n.reshapeJawline, 'icon': Icons.linear_scale},
      {'id': 'doubleChin', 'label': l10n.reshapeDoubleChin, 'icon': Icons.expand_more},
      {'id': 'cheekWidth', 'label': l10n.reshapeCheek, 'icon': Icons.aspect_ratio},
      {'id': 'chinLength', 'label': l10n.reshapeChinLen, 'icon': Icons.height},
      {'id': 'chinWidth', 'label': l10n.reshapeChinWid, 'icon': Icons.straighten},
      {'id': 'forehead', 'label': l10n.reshapeForehead, 'icon': Icons.expand_less},
      {'id': 'hairline', 'label': l10n.reshapeHairline, 'icon': Icons.vertical_align_top},
      {'id': 'templeWidth', 'label': l10n.reshapeTemple, 'icon': Icons.width_wide},
    ];

    final noseTools = [
      {'id': 'noseWidth', 'label': l10n.reshapeNoseWid, 'icon': Icons.tune},
      {'id': 'noseBridge', 'label': l10n.reshapeNoseBridge, 'icon': Icons.linear_scale},
      {'id': 'noseTip', 'label': l10n.reshapeNoseTip, 'icon': Icons.adjust},
      {'id': 'noseLength', 'label': l10n.reshapeNoseLen, 'icon': Icons.height},
      {'id': 'nostrilWidth', 'label': l10n.reshapeNostril, 'icon': Icons.filter_tilt_shift},
    ];

    final eyeTools = [
      {'id': 'eyeSize', 'label': l10n.reshapeEyeSize, 'icon': Icons.remove_red_eye},
      {'id': 'aegyoSal', 'label': l10n.reshapeAegyoSal, 'icon': Icons.sentiment_satisfied},
      {'id': 'eyeDistance', 'label': l10n.reshapeEyeDist, 'icon': Icons.space_bar},
      {'id': 'eyeHeight', 'label': l10n.reshapeEyeHeight, 'icon': Icons.height},
      {'id': 'eyeAngle', 'label': l10n.reshapeEyeAngle, 'icon': Icons.rotate_right},
      {'id': 'eyeBrightness', 'label': l10n.reshapeEyeBrighten, 'icon': Icons.brightness_medium},
      {'id': 'eyeSparkle', 'label': l10n.reshapeEyeSparkle, 'icon': Icons.auto_awesome},
    ];

    final eyebrowTools = [
      {'id': 'eyebrowHeight', 'label': l10n.reshapeEyebrowHeight, 'icon': Icons.swap_vert},
      {'id': 'eyebrowArch', 'label': l10n.reshapeEyebrowArch, 'icon': Icons.trending_up},
      {'id': 'eyebrowTilt', 'label': l10n.reshapeEyebrowTilt, 'icon': Icons.rotate_right},
    ];

    final mouthTools = [
      {'id': 'smile', 'label': l10n.reshapeSmile, 'icon': Icons.sentiment_satisfied_alt},
      {'id': 'smileCorners', 'label': l10n.reshapeSmileCorners, 'icon': Icons.mood},
      {'id': 'mShapeLips', 'label': l10n.reshapeMShapeLips, 'icon': Icons.favorite_border},
      {'id': 'teethWhitening', 'label': l10n.beautyTeethWhitening, 'icon': Icons.auto_awesome},
      {'id': 'mouthWidth', 'label': l10n.reshapeMouthWid, 'icon': Icons.panorama_horizontal},
      {'id': 'mouthSize', 'label': l10n.reshapeMouthSize, 'icon': Icons.photo_size_select_small},
      {'id': 'lipThickness', 'label': l10n.reshapeLipThick, 'icon': Icons.line_weight},
      {'id': 'mouthPosition', 'label': l10n.reshapeMouthPos, 'icon': Icons.unfold_more},
    ];

    final groups = [
      {'id': 'face', 'label': l10n.groupFace},
      {'id': 'eyebrow', 'label': l10n.groupEyebrow},
      {'id': 'eyes', 'label': l10n.groupEyes},
      {'id': 'nose', 'label': l10n.groupNose},
      {'id': 'mouth', 'label': l10n.groupMouth},
    ];

    String currentGroup = 'face';
    if (eyebrowTools.any((t) => t['id'] == subTool)) {
      currentGroup = 'eyebrow';
    } else if (noseTools.any((t) => t['id'] == subTool)) {
      currentGroup = 'nose';
    } else if (eyeTools.any((t) => t['id'] == subTool)) {
      currentGroup = 'eyes';
    } else if (mouthTools.any((t) => t['id'] == subTool)) {
      currentGroup = 'mouth';
    }

    void onSelectGroup(String groupId) {
      switch (groupId) {
        case 'eyebrow':
          controller.selectSubTool('eyebrowHeight');
          break;
        case 'nose':
          controller.selectSubTool('noseWidth');
          break;
        case 'eyes':
          controller.selectSubTool('eyeSize');
          break;
        case 'mouth':
          controller.selectSubTool('smile');
          break;
        case 'face':
        default:
          controller.selectSubTool('slimFace');
          break;
      }
    }

    bool isGroupModified(String groupId) {
      switch (groupId) {
        case 'eyebrow':
          return f.eyebrowHeight != 0 || f.eyebrowArch != 0 || f.eyebrowTilt != 0;
        case 'nose':
          return f.noseWidth != 0 || f.noseBridge != 0 || f.noseTip != 0 || f.noseLength != 0 || f.nostrilWidth != 0;
        case 'eyes':
          return f.eyeSize != 0 || f.aegyoSal != 0 || f.eyeDistance != 0 || f.eyeHeight != 0 || f.eyeAngle != 0 || f.eyeBrightness != 0 || f.eyeSparkle != 0 || f.eyeSparkleStyle != 'starlight';
        case 'mouth':
          return f.smile != 0 || f.smileCorners != 0 || f.mShapeLips != 0 || f.mouthWidth != 0 || f.mouthSize != 0 || f.lipThickness != 0 || f.mouthPosition != 0 || b.teethWhitening > 0;
        case 'face':
        default:
          return f.slimFace != 0 || f.smallFace != 0 || f.vFace != 0 || f.jawWidth != 0 || f.jawline != 0 || f.doubleChin != 0 || f.cheekWidth != 0 || f.chinLength != 0 || f.chinWidth != 0 || f.forehead != 0 || f.hairline != 0 || f.templeWidth != 0;
      }
    }

    List<Map<String, dynamic>> currentTools;
    switch (currentGroup) {
      case 'eyebrow':
        currentTools = eyebrowTools;
        break;
      case 'nose':
        currentTools = noseTools;
        break;
      case 'eyes':
        currentTools = eyeTools;
        break;
      case 'mouth':
        currentTools = mouthTools;
        break;
      case 'face':
      default:
        currentTools = faceTools;
        break;
    }

    Widget buildCurrentSlider() {
      switch (subTool) {
        // Face
        case 'slimFace':
          return BeautySlider(
            label: l10n.reshapeSlimFace,
            value: f.slimFace,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(slimFace: v)),
          );
        case 'smallFace':
          return BeautySlider(
            label: l10n.reshapeSmallFace,
            value: f.smallFace,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(smallFace: v)),
          );
        case 'vFace':
          return BeautySlider(
            label: l10n.sliderVLineFace,
            value: f.vFace,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(vFace: v)),
          );
        case 'jawWidth':
          return BeautySlider(
            label: l10n.sliderJawWidth,
            value: f.jawWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(jawWidth: v)),
          );
        case 'jawline':
          return BeautySlider(
            label: l10n.reshapeJawline,
            value: f.jawline,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(jawline: v)),
          );
        case 'doubleChin':
          return BeautySlider(
            label: l10n.reshapeDoubleChin,
            value: f.doubleChin,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(doubleChin: v)),
          );
        case 'cheekWidth':
          return BeautySlider(
            label: l10n.sliderCheekbones,
            value: f.cheekWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(cheekWidth: v)),
          );
        case 'chinLength':
          return BeautySlider(
            label: l10n.sliderChinLength,
            value: f.chinLength,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(chinLength: v)),
          );
        case 'chinWidth':
          return BeautySlider(
            label: l10n.sliderChinWidth,
            value: f.chinWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(chinWidth: v)),
          );
        case 'forehead':
          return BeautySlider(
            label: l10n.sliderForeheadHeight,
            value: f.forehead,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(forehead: v)),
          );
        case 'hairline':
          return BeautySlider(
            label: l10n.sliderHairline,
            value: f.hairline,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(hairline: v)),
          );
        case 'templeWidth':
          return BeautySlider(
            label: l10n.sliderTemple,
            value: f.templeWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(templeWidth: v)),
          );

        // Nose
        case 'noseWidth':
          return BeautySlider(
            label: l10n.sliderNoseWidth,
            value: f.noseWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(noseWidth: v)),
          );
        case 'noseBridge':
          return BeautySlider(
            label: l10n.sliderNoseBridge,
            value: f.noseBridge,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(noseBridge: v)),
          );
        case 'noseTip':
          return BeautySlider(
            label: l10n.sliderNoseTip,
            value: f.noseTip,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(noseTip: v)),
          );
        case 'noseLength':
          return BeautySlider(
            label: l10n.sliderNoseLength,
            value: f.noseLength,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(noseLength: v)),
          );
        case 'nostrilWidth':
          return BeautySlider(
            label: l10n.sliderNostrilWidth,
            value: f.nostrilWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(nostrilWidth: v)),
          );

        // Eyes
        case 'eyeSize':
          return BeautySlider(
            label: l10n.sliderBigEyes,
            value: f.eyeSize,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyeSize: v)),
          );
        case 'aegyoSal':
          return BeautySlider(
            label: l10n.reshapeAegyoSal,
            value: f.aegyoSal,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(aegyoSal: v)),
          );
        case 'eyeDistance':
          return BeautySlider(
            label: l10n.sliderEyeDistance,
            value: f.eyeDistance,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyeDistance: v)),
          );
        case 'eyeHeight':
          return BeautySlider(
            label: l10n.sliderEyeHeight,
            value: f.eyeHeight,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyeHeight: v)),
          );
        case 'eyeAngle':
          return BeautySlider(
            label: l10n.sliderEyeAngle,
            value: f.eyeAngle,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyeAngle: v)),
          );
        case 'eyeBrightness':
          return BeautySlider(
            label: l10n.sliderEyeBrightness,
            value: f.eyeBrightness,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyeBrightness: v)),
          );
        case 'eyeSparkle':
          final sparkleStyles = [
            {'id': 'starlight', 'label': l10n.sparkleStarlight, 'icon': Icons.star_border},
            {'id': 'natural', 'label': l10n.sparkleNatural, 'icon': Icons.wb_sunny_outlined},
            {'id': 'ring', 'label': l10n.sparkleRing, 'icon': Icons.panorama_fish_eye},
            {'id': 'crystal', 'label': l10n.sparkleCrystal, 'icon': Icons.diamond_outlined},
            {'id': 'heart', 'label': l10n.sparkleHeart, 'icon': Icons.favorite_border},
            {'id': 'crescent', 'label': l10n.sparkleCrescent, 'icon': Icons.nightlight_round},
            {'id': 'starburst', 'label': l10n.sparkleStarburst, 'icon': Icons.flare},
            {'id': 'galaxy', 'label': l10n.sparkleGalaxy, 'icon': Icons.grain},
            {'id': 'pearl', 'label': l10n.sparklePearl, 'icon': Icons.blur_circular},
            {'id': 'butterfly', 'label': l10n.sparkleButterfly, 'icon': Icons.filter_vintage_outlined},
          ];
          return Row(
            children: [
              Expanded(
                child: BeautySlider(
                  label: l10n.sliderSparklingEyes,
                  value: f.eyeSparkle,
                  defaultValue: 0,
                  onChanged: (v) => controller.updateFace(f.copyWith(eyeSparkle: v)),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF222227),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final style in sparkleStyles)
                        GestureDetector(
                          onTap: () => controller.updateFace(f.copyWith(
                            eyeSparkleStyle: style['id'] as String,
                            eyeSparkle: f.eyeSparkle == 0 ? 50 : f.eyeSparkle,
                          )),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                            decoration: BoxDecoration(
                              color: f.eyeSparkleStyle == style['id'] ? const Color(0xFF6C5CE7) : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  style['icon'] as IconData,
                                  size: 13,
                                  color: f.eyeSparkleStyle == style['id'] ? Colors.white : Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  style['label'] as String,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: f.eyeSparkleStyle == style['id'] ? FontWeight.w600 : FontWeight.w400,
                                    color: f.eyeSparkleStyle == style['id'] ? Colors.white : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );

        // Eyebrows
        case 'eyebrowHeight':
          return BeautySlider(
            label: l10n.sliderEyebrowHeight,
            value: f.eyebrowHeight,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyebrowHeight: v)),
          );
        case 'eyebrowArch':
          return BeautySlider(
            label: l10n.sliderEyebrowArch,
            value: f.eyebrowArch,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyebrowArch: v)),
          );
        case 'eyebrowTilt':
          return BeautySlider(
            label: l10n.sliderEyebrowTilt,
            value: f.eyebrowTilt,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyebrowTilt: v)),
          );

        // Mouth
        case 'smile':
          return BeautySlider(
            label: l10n.sliderSmileLift,
            value: f.smile,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(smile: v)),
          );
        case 'smileCorners':
          return BeautySlider(
            label: l10n.sliderSmileCorners,
            value: f.smileCorners,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(smileCorners: v)),
          );
        case 'mShapeLips':
          return BeautySlider(
            label: l10n.sliderHeartLips,
            value: f.mShapeLips,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(mShapeLips: v)),
          );
        case 'teethWhitening':
          return BeautySlider(
            label: l10n.sliderTeethWhitening,
            value: b.teethWhitening,
            defaultValue: 0,
            onChanged: (v) => controller.updateBeauty(b.copyWith(teethWhitening: v)),
          );
        case 'mouthWidth':
          return BeautySlider(
            label: l10n.sliderMouthWidth,
            value: f.mouthWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(mouthWidth: v)),
          );
        case 'mouthSize':
          return BeautySlider(
            label: l10n.sliderMouthSize,
            value: f.mouthSize,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(mouthSize: v)),
          );
        case 'lipThickness':
          return BeautySlider(
            label: l10n.sliderLipThickness,
            value: f.lipThickness,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(lipThickness: v)),
          );
        case 'mouthPosition':
          return BeautySlider(
            label: l10n.sliderMouthPosition,
            value: f.mouthPosition,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(mouthPosition: v)),
          );

        default:
          return BeautySlider(
            label: l10n.reshapeSlimFace,
            value: f.slimFace,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(slimFace: v)),
          );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Group Selector (Face / Eyebrow / Eyes / Nose / Mouth) + Active Tool Slider
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 14),
              // Group Pills
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF222227),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final g in groups)
                      GestureDetector(
                        onTap: () => onSelectGroup(g['id'] as String),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: currentGroup == g['id']
                                ? const Color(0xFFFF7597)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                g['label'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: currentGroup == g['id']
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: currentGroup == g['id']
                                      ? Colors.white
                                      : Colors.white60,
                                ),
                              ),
                              if (isGroupModified(g['id'] as String) && currentGroup != g['id']) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF7597),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Active Slider
              Expanded(
                child: buildCurrentSlider(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white10),
        // Row 2: Reset button + Tools of the active group
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white54),
                tooltip: l10n.resetFaceTooltip,
                onPressed: f.isModified ? () => controller.resetFace() : null,
              ),
              const SizedBox(width: 4),
              for (final t in currentTools)
                ToolButton(
                  label: t['label'] as String,
                  icon: t['icon'] as IconData,
                  isSelected: subTool == t['id'],
                  isActive: t['id'] == 'teethWhitening'
                      ? b.teethWhitening > 0
                      : f.isKeyActive(t['id'] as String),
                  onTap: () => controller.selectSubTool(t['id'] as String),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
