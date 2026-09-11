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
    final subTool = state.activeSubTool;

    final tools = [
      {'id': 'slimFace', 'label': 'Slim Face', 'icon': Icons.face_retouching_natural},
      {'id': 'smallFace', 'label': 'Small Face', 'icon': Icons.compress},
      {'id': 'vFace', 'label': 'V Face', 'icon': Icons.arrow_downward},
      {'id': 'jawWidth', 'label': 'Jaw', 'icon': Icons.swap_horiz},
      {'id': 'cheekWidth', 'label': 'Cheek', 'icon': Icons.aspect_ratio},
      {'id': 'chinLength', 'label': 'Chin Len', 'icon': Icons.height},
      {'id': 'chinWidth', 'label': 'Chin Wid', 'icon': Icons.straighten},
      {'id': 'forehead', 'label': 'Forehead', 'icon': Icons.expand_less},
      {'id': 'templeWidth', 'label': 'Temple', 'icon': Icons.width_wide},
      {'id': 'eyeSize', 'label': 'Eye Size', 'icon': Icons.remove_red_eye},
      {'id': 'eyeDistance', 'label': 'Eye Dist', 'icon': Icons.space_bar},
      {'id': 'eyeBrightness', 'label': 'Eye Glow', 'icon': Icons.flare},
      {'id': 'noseWidth', 'label': 'Nose Wid', 'icon': Icons.tune},
      {'id': 'noseBridge', 'label': 'Nose Bridge', 'icon': Icons.linear_scale},
      {'id': 'mouthWidth', 'label': 'Mouth Wid', 'icon': Icons.panorama_horizontal},
      {'id': 'smile', 'label': 'Smile', 'icon': Icons.sentiment_satisfied_alt},
    ];

    Widget buildCurrentSlider() {
      switch (subTool) {
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
        case 'eyeBrightness':
          return BeautySlider(
            label: 'Eye Brightness',
            value: f.eyeBrightness,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(eyeBrightness: v)),
          );
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
        case 'mouthWidth':
          return BeautySlider(
            label: 'Mouth Width',
            value: f.mouthWidth,
            min: -50,
            max: 50,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(mouthWidth: v)),
          );
        case 'smile':
          return BeautySlider(
            label: 'Smile Lift',
            value: f.smile,
            defaultValue: 0,
            onChanged: (v) => controller.updateFace(f.copyWith(smile: v)),
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildCurrentSlider(),
        const Divider(height: 1, color: Colors.white10),
        SizedBox(
          height: 52,
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
              for (final t in tools)
                ToolButton(
                  label: t['label'] as String,
                  icon: t['icon'] as IconData,
                  isSelected: subTool == t['id'],
                  isActive: f.isKeyActive(t['id'] as String),
                  onTap: () => controller.selectSubTool(t['id'] as String),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
