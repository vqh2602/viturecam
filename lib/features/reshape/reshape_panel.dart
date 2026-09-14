import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/beauty_slider.dart';
import '../../widgets/tool_button.dart';
import '../camera/camera_controller.dart';

class ReshapePanel extends ConsumerWidget {
  const ReshapePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final f = state.face;
    final b = state.beauty;
    final subTool = state.activeSubTool;

    final faceTools = [
      {'id': 'slimFace', 'label': 'Slim Face', 'icon': Icons.face_retouching_natural},
      {'id': 'smallFace', 'label': 'Small Face', 'icon': Icons.compress},
      {'id': 'vFace', 'label': 'V Face', 'icon': Icons.arrow_downward},
      {'id': 'jawWidth', 'label': 'Jaw', 'icon': Icons.swap_horiz},
      {'id': 'cheekWidth', 'label': 'Cheek', 'icon': Icons.aspect_ratio},
      {'id': 'chinLength', 'label': 'Chin Len', 'icon': Icons.height},
      {'id': 'chinWidth', 'label': 'Chin Wid', 'icon': Icons.straighten},
      {'id': 'forehead', 'label': 'Forehead', 'icon': Icons.expand_less},
      {'id': 'templeWidth', 'label': 'Temple', 'icon': Icons.width_wide},
    ];

    final noseTools = [
      {'id': 'noseWidth', 'label': 'Nose Wid', 'icon': Icons.tune},
      {'id': 'noseBridge', 'label': 'Nose Bridge', 'icon': Icons.linear_scale},
      {'id': 'noseTip', 'label': 'Nose Tip', 'icon': Icons.adjust},
      {'id': 'noseLength', 'label': 'Nose Len', 'icon': Icons.height},
      {'id': 'nostrilWidth', 'label': 'Nostril', 'icon': Icons.filter_tilt_shift},
    ];

    final eyeTools = [
      {'id': 'eyeSize', 'label': 'Eye Size', 'icon': Icons.remove_red_eye},
      {'id': 'eyeDistance', 'label': 'Eye Dist', 'icon': Icons.space_bar},
      {'id': 'eyeHeight', 'label': 'Eye Height', 'icon': Icons.height},
      {'id': 'eyeAngle', 'label': 'Eye Angle', 'icon': Icons.rotate_right},
      {'id': 'eyeBrightness', 'label': 'Eye Glow', 'icon': Icons.flare},
    ];

    final mouthTools = [
      {'id': 'smile', 'label': 'Smile', 'icon': Icons.sentiment_satisfied_alt},
      {'id': 'smileCorners', 'label': 'Khóe cười', 'icon': Icons.mood},
      {'id': 'mShapeLips', 'label': 'Môi chữ M', 'icon': Icons.favorite_border},
      {'id': 'teethWhitening', 'label': 'Trắng răng', 'icon': Icons.auto_awesome},
      {'id': 'mouthWidth', 'label': 'Mouth Wid', 'icon': Icons.panorama_horizontal},
      {'id': 'mouthSize', 'label': 'Mouth Size', 'icon': Icons.photo_size_select_small},
      {'id': 'lipThickness', 'label': 'Lip Thick', 'icon': Icons.line_weight},
      {'id': 'mouthPosition', 'label': 'Position', 'icon': Icons.unfold_more},
    ];

    final groups = [
      {'id': 'face', 'label': 'Mặt'},
      {'id': 'nose', 'label': 'Mũi'},
      {'id': 'eyes', 'label': 'Mắt'},
      {'id': 'mouth', 'label': 'Miệng'},
    ];

    String currentGroup = 'face';
    if (noseTools.any((t) => t['id'] == subTool)) {
      currentGroup = 'nose';
    } else if (eyeTools.any((t) => t['id'] == subTool)) {
      currentGroup = 'eyes';
    } else if (mouthTools.any((t) => t['id'] == subTool)) {
      currentGroup = 'mouth';
    }

    void onSelectGroup(String groupId) {
      switch (groupId) {
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
        case 'nose':
          return f.noseWidth != 0 || f.noseBridge != 0 || f.noseTip != 0 || f.noseLength != 0 || f.nostrilWidth != 0;
        case 'eyes':
          return f.eyeSize != 0 || f.eyeDistance != 0 || f.eyeHeight != 0 || f.eyeAngle != 0 || f.eyeBrightness != 0;
        case 'mouth':
          return f.smile != 0 || f.smileCorners != 0 || f.mShapeLips != 0 || f.mouthWidth != 0 || f.mouthSize != 0 || f.lipThickness != 0 || f.mouthPosition != 0 || b.teethWhitening > 0;
        case 'face':
        default:
          return f.slimFace != 0 || f.smallFace != 0 || f.vFace != 0 || f.jawWidth != 0 || f.cheekWidth != 0 || f.chinLength != 0 || f.chinWidth != 0 || f.forehead != 0 || f.templeWidth != 0;
      }
    }

    List<Map<String, dynamic>> currentTools;
    switch (currentGroup) {
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
            label: 'Slim Face',
            value: f.slimFace,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(slimFace: v)),
          );
        case 'smallFace':
          return BeautySlider(
            label: 'Small Face',
            value: f.smallFace,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(smallFace: v)),
          );
        case 'vFace':
          return BeautySlider(
            label: 'V-Line Face',
            value: f.vFace,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(vFace: v)),
          );
        case 'jawWidth':
          return BeautySlider(
            label: 'Jaw Width',
            value: f.jawWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(jawWidth: v)),
          );
        case 'cheekWidth':
          return BeautySlider(
            label: 'Cheek Width',
            value: f.cheekWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(cheekWidth: v)),
          );
        case 'chinLength':
          return BeautySlider(
            label: 'Chin Length',
            value: f.chinLength,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(chinLength: v)),
          );
        case 'chinWidth':
          return BeautySlider(
            label: 'Chin Width',
            value: f.chinWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(chinWidth: v)),
          );
        case 'forehead':
          return BeautySlider(
            label: 'Forehead Height',
            value: f.forehead,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(forehead: v)),
          );
        case 'templeWidth':
          return BeautySlider(
            label: 'Temple Width',
            value: f.templeWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(templeWidth: v)),
          );

        // Nose
        case 'noseWidth':
          return BeautySlider(
            label: 'Nose Width',
            value: f.noseWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(noseWidth: v)),
          );
        case 'noseBridge':
          return BeautySlider(
            label: 'Nose Bridge',
            value: f.noseBridge,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(noseBridge: v)),
          );
        case 'noseTip':
          return BeautySlider(
            label: 'Nose Tip',
            value: f.noseTip,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(noseTip: v)),
          );
        case 'noseLength':
          return BeautySlider(
            label: 'Nose Length',
            value: f.noseLength,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(noseLength: v)),
          );
        case 'nostrilWidth':
          return BeautySlider(
            label: 'Nostril Width',
            value: f.nostrilWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(nostrilWidth: v)),
          );

        // Eyes
        case 'eyeSize':
          return BeautySlider(
            label: 'Big Eyes',
            value: f.eyeSize,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyeSize: v)),
          );
        case 'eyeDistance':
          return BeautySlider(
            label: 'Eye Distance',
            value: f.eyeDistance,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyeDistance: v)),
          );
        case 'eyeHeight':
          return BeautySlider(
            label: 'Eye Height',
            value: f.eyeHeight,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyeHeight: v)),
          );
        case 'eyeAngle':
          return BeautySlider(
            label: 'Eye Angle',
            value: f.eyeAngle,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyeAngle: v)),
          );
        case 'eyeBrightness':
          return BeautySlider(
            label: 'Eye Brightness',
            value: f.eyeBrightness,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyeBrightness: v)),
          );

        // Mouth
        case 'smile':
          return BeautySlider(
            label: 'Smile Lift',
            value: f.smile,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(smile: v)),
          );
        case 'smileCorners':
          return BeautySlider(
            label: 'Khóe cười (Smile Corners)',
            value: f.smileCorners,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(smileCorners: v)),
          );
        case 'mShapeLips':
          return BeautySlider(
            label: 'Môi chữ M / Trái tim (Heart Lips)',
            value: f.mShapeLips,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(mShapeLips: v)),
          );
        case 'teethWhitening':
          return BeautySlider(
            label: 'Trắng răng (Teeth Whitening)',
            value: b.teethWhitening,
            defaultValue: 0,
            onChanged: (v) => controller.updateBeauty(b.copyWith(teethWhitening: v)),
          );
        case 'mouthWidth':
          return BeautySlider(
            label: 'Mouth Width',
            value: f.mouthWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(mouthWidth: v)),
          );
        case 'mouthSize':
          return BeautySlider(
            label: 'Mouth Size',
            value: f.mouthSize,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(mouthSize: v)),
          );
        case 'lipThickness':
          return BeautySlider(
            label: 'Lip Thickness',
            value: f.lipThickness,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(lipThickness: v)),
          );
        case 'mouthPosition':
          return BeautySlider(
            label: 'Mouth Position',
            value: f.mouthPosition,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(mouthPosition: v)),
          );

        default:
          return BeautySlider(
            label: 'Slim Face',
            value: f.slimFace,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(slimFace: v)),
          );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Group Selector (Mặt / Mũi / Mắt / Miệng) + Active Tool Slider
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
                tooltip: 'Reset Face',
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
