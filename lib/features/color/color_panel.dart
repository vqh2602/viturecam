import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/beauty_slider.dart';
import '../../widgets/tool_button.dart';
import '../camera/camera_controller.dart';

class ColorPanel extends ConsumerWidget {
  const ColorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final c = state.color;
    final subTool = state.activeSubTool;

    final tools = [
      {'id': 'exposure', 'label': 'Exposure', 'icon': Icons.exposure},
      {'id': 'brightness', 'label': 'Brightness', 'icon': Icons.brightness_medium},
      {'id': 'contrast', 'label': 'Contrast', 'icon': Icons.contrast},
      {'id': 'highlights', 'label': 'Highlights', 'icon': Icons.wb_sunny},
      {'id': 'shadows', 'label': 'Shadows', 'icon': Icons.nightlight_round},
      {'id': 'saturation', 'label': 'Saturation', 'icon': Icons.color_lens},
      {'id': 'temperature', 'label': 'Temperature', 'icon': Icons.thermostat},
      {'id': 'tint', 'label': 'Tint', 'icon': Icons.invert_colors},
      {'id': 'sharpness', 'label': 'Sharpness', 'icon': Icons.details},
    ];

    Widget buildCurrentSlider() {
      switch (subTool) {
        case 'exposure':
          return BeautySlider(
            label: 'Exposure',
            value: c.exposure,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(exposure: v)),
          );
        case 'brightness':
          return BeautySlider(
            label: 'Brightness',
            value: c.brightness,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(brightness: v)),
          );
        case 'contrast':
          return BeautySlider(
            label: 'Contrast',
            value: c.contrast,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(contrast: v)),
          );
        case 'highlights':
          return BeautySlider(
            label: 'Highlights',
            value: c.highlights,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(highlights: v)),
          );
        case 'shadows':
          return BeautySlider(
            label: 'Shadows',
            value: c.shadows,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(shadows: v)),
          );
        case 'saturation':
          return BeautySlider(
            label: 'Saturation',
            value: c.saturation,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(saturation: v)),
          );
        case 'temperature':
          return BeautySlider(
            label: 'Color Temperature',
            value: c.temperature,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(temperature: v)),
          );
        case 'tint':
          return BeautySlider(
            label: 'Color Tint',
            value: c.tint,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(tint: v)),
          );
        case 'sharpness':
          return BeautySlider(
            label: 'Detail Sharpness',
            value: c.sharpness,
            min: 0,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(sharpness: v)),
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
                tooltip: 'Reset Color',
                onPressed: c.isModified ? () => controller.resetColor() : null,
              ),
              const SizedBox(width: 4),
              for (final t in tools)
                ToolButton(
                  label: t['label'] as String,
                  icon: t['icon'] as IconData,
                  isSelected: subTool == t['id'],
                  isActive: c.isKeyActive(t['id'] as String),
                  onTap: () => controller.selectSubTool(t['id'] as String),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
