import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/beauty_slider.dart';
import '../../widgets/tool_button.dart';
import '../camera/camera_controller.dart';

class BeautyPanel extends ConsumerWidget {
  const BeautyPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final b = state.beauty;
    final subTool = state.activeSubTool;

    final tools = [
      {'id': 'smooth', 'label': 'Smooth', 'icon': Icons.blur_on},
      {'id': 'skinTexture', 'label': 'Texture', 'icon': Icons.grain},
      {'id': 'skinBrightness', 'label': 'Brighten', 'icon': Icons.brightness_6},
      {'id': 'whitening', 'label': 'Whitening', 'icon': Icons.wb_sunny_outlined},
      {'id': 'redness', 'label': 'Redness', 'icon': Icons.spa_outlined},
      {'id': 'darkCircle', 'label': 'Dark Circle', 'icon': Icons.remove_red_eye_outlined},
      {'id': 'eyeBag', 'label': 'Eye Bag', 'icon': Icons.visibility_outlined},
      {'id': 'teethWhitening', 'label': 'Teeth', 'icon': Icons.sentiment_very_satisfied},
    ];

    Widget buildCurrentSlider() {
      switch (subTool) {
        case 'smooth':
          return BeautySlider(
            label: 'Skin Smoothing',
            value: b.smooth,
            defaultValue: 0,
            onChanged: (v) => controller.updateBeauty(b.copyWith(smooth: v)),
          );
        case 'skinTexture':
          return BeautySlider(
            label: 'Texture Preservation',
            value: b.skinTexture,
            defaultValue: 50,
            onChanged: (v) => controller.updateBeauty(b.copyWith(skinTexture: v)),
          );
        case 'skinBrightness':
          return BeautySlider(
            label: 'Skin Brightness',
            value: b.skinBrightness,
            defaultValue: 0,
            onChanged: (v) => controller.updateBeauty(b.copyWith(skinBrightness: v)),
          );
        case 'whitening':
          return BeautySlider(
            label: 'Skin Whitening',
            value: b.whitening,
            defaultValue: 0,
            onChanged: (v) => controller.updateBeauty(b.copyWith(whitening: v)),
          );
        case 'redness':
          return BeautySlider(
            label: 'Redness Reduction',
            value: b.redness,
            defaultValue: 0,
            onChanged: (v) => controller.updateBeauty(b.copyWith(redness: v)),
          );
        case 'darkCircle':
          return BeautySlider(
            label: 'Dark Circle Reduction',
            value: b.darkCircle,
            defaultValue: 0,
            onChanged: (v) => controller.updateBeauty(b.copyWith(darkCircle: v)),
          );
        case 'eyeBag':
          return BeautySlider(
            label: 'Eye Bag Reduction',
            value: b.eyeBag,
            defaultValue: 0,
            onChanged: (v) => controller.updateBeauty(b.copyWith(eyeBag: v)),
          );
        case 'teethWhitening':
          return BeautySlider(
            label: 'Teeth Whitening',
            value: b.teethWhitening,
            defaultValue: 0,
            onChanged: (v) => controller.updateBeauty(b.copyWith(teethWhitening: v)),
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
              // Reset category
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white54),
                tooltip: 'Reset Beauty',
                onPressed: b.isModified ? () => controller.resetBeauty() : null,
              ),
              const SizedBox(width: 4),
              for (final t in tools)
                ToolButton(
                  label: t['label'] as String,
                  icon: t['icon'] as IconData,
                  isSelected: subTool == t['id'],
                  isActive: b.isKeyActive(t['id'] as String),
                  onTap: () => controller.selectSubTool(t['id'] as String),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
