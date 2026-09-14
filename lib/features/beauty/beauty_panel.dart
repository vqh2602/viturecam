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
      {'id': 'skinTone', 'label': 'Skin Tone', 'icon': Icons.palette_outlined},
      {'id': 'skinBrightness', 'label': 'Brighten', 'icon': Icons.brightness_6},
      {'id': 'whitening', 'label': 'Whitening', 'icon': Icons.wb_sunny_outlined},
      {'id': 'teethWhitening', 'label': 'Trắng răng', 'icon': Icons.auto_awesome},
      {'id': 'redness', 'label': 'Redness', 'icon': Icons.spa_outlined},
      {'id': 'darkCircle', 'label': 'Dark Circle', 'icon': Icons.remove_red_eye_outlined},
      {'id': 'eyeBag', 'label': 'Eye Bag', 'icon': Icons.visibility_outlined},
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
        case 'skinTone':
          final toneTypes = [
            {'id': 'natural', 'label': 'Tự nhiên', 'color': const Color(0xFFF7D5C8)},
            {'id': 'porcelain', 'label': 'Trắng sứ', 'color': const Color(0xFFFFF0EA)},
            {'id': 'snow', 'label': 'Tuyết lạnh', 'color': const Color(0xFFF5F5FF)},
            {'id': 'rosy', 'label': 'Trắng hồng', 'color': const Color(0xFFFFE0E5)},
            {'id': 'cherry', 'label': 'Anh đào', 'color': const Color(0xFFFFDDE6)},
            {'id': 'peach', 'label': 'Hồng đào', 'color': const Color(0xFFFFD1BA)},
            {'id': 'coral', 'label': 'San hô', 'color': const Color(0xFFFFCBA4)},
            {'id': 'warm', 'label': 'Nắng ấm', 'color': const Color(0xFFFFD4A0)},
            {'id': 'honey', 'label': 'Mật ong', 'color': const Color(0xFFECC08C)},
            {'id': 'wheat', 'label': 'Lúa mì', 'color': const Color(0xFFDEB887)},
            {'id': 'olive', 'label': 'Ô-liu', 'color': const Color(0xFFD0C09E)},
            {'id': 'tan', 'label': 'Bánh mật', 'color': const Color(0xFFCF9C7A)},
          ];
          return Row(
            children: [
              const SizedBox(width: 12),
              Container(
                width: 360,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF222227),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tone in toneTypes)
                        GestureDetector(
                          onTap: () => controller.updateBeauty(b.copyWith(
                            skinToneType: tone['id'] as String,
                            skinTone: b.skinTone == 0 ? 60 : b.skinTone,
                          )),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: b.skinToneType == tone['id']
                                  ? const Color(0xFFFF7597).withValues(alpha: 0.25)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: b.skinToneType == tone['id']
                                  ? Border.all(color: const Color(0xFFFF7597), width: 1.2)
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: tone['color'] as Color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white38, width: 0.8),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  tone['label'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: b.skinToneType == tone['id'] ? FontWeight.w600 : FontWeight.w400,
                                    color: b.skinToneType == tone['id'] ? Colors.white : Colors.white70,
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
              const SizedBox(width: 8),
              Expanded(
                child: BeautySlider(
                  label: 'Skin Tone Intensity',
                  value: b.skinTone,
                  defaultValue: 0,
                  onChanged: (v) => controller.updateBeauty(b.copyWith(skinTone: v)),
                ),
              ),
            ],
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
          return BeautySlider(
            label: 'Skin Smoothing',
            value: b.smooth,
            defaultValue: 0,
            onChanged: (v) => controller.updateBeauty(b.copyWith(smooth: v)),
          );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: buildCurrentSlider(),
        ),
        const Divider(height: 1, color: Colors.white10),
        SizedBox(
          height: 56,
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
