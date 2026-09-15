import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/beauty_slider.dart';
import '../../widgets/tool_button.dart';
import '../camera/camera_controller.dart';

class ColorPanel extends ConsumerWidget {
  const ColorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final c = state.color;
    final subTool = state.activeSubTool;

    final tools = [
      {'id': 'exposure', 'label': l10n.colorExposure, 'icon': Icons.exposure},
      {'id': 'brightness', 'label': l10n.colorBrightness, 'icon': Icons.brightness_medium},
      {'id': 'contrast', 'label': l10n.colorContrast, 'icon': Icons.contrast},
      {'id': 'highlights', 'label': l10n.colorHighlights, 'icon': Icons.wb_sunny},
      {'id': 'shadows', 'label': l10n.colorShadows, 'icon': Icons.nightlight_round},
      {'id': 'saturation', 'label': l10n.colorSaturation, 'icon': Icons.color_lens},
      {'id': 'temperature', 'label': l10n.colorTemperature, 'icon': Icons.thermostat},
      {'id': 'tint', 'label': l10n.colorTint, 'icon': Icons.invert_colors},
      {'id': 'sharpness', 'label': l10n.colorSharpness, 'icon': Icons.details},
    ];

    Widget buildCurrentSlider() {
      switch (subTool) {
        case 'exposure':
          return BeautySlider(
            label: l10n.colorExposure,
            value: c.exposure,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(exposure: v)),
          );
        case 'brightness':
          return BeautySlider(
            label: l10n.colorBrightness,
            value: c.brightness,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(brightness: v)),
          );
        case 'contrast':
          return BeautySlider(
            label: l10n.colorContrast,
            value: c.contrast,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(contrast: v)),
          );
        case 'highlights':
          return BeautySlider(
            label: l10n.colorHighlights,
            value: c.highlights,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(highlights: v)),
          );
        case 'shadows':
          return BeautySlider(
            label: l10n.colorShadows,
            value: c.shadows,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(shadows: v)),
          );
        case 'saturation':
          return BeautySlider(
            label: l10n.colorSaturation,
            value: c.saturation,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(saturation: v)),
          );
        case 'temperature':
          return BeautySlider(
            label: l10n.sliderColorTemperature,
            value: c.temperature,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(temperature: v)),
          );
        case 'tint':
          return BeautySlider(
            label: l10n.sliderColorTint,
            value: c.tint,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(tint: v)),
          );
        case 'sharpness':
          return BeautySlider(
            label: l10n.sliderDetailSharpness,
            value: c.sharpness,
            min: 0,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(sharpness: v)),
          );
        default:
          return BeautySlider(
            label: l10n.colorExposure,
            value: c.exposure,
            min: -100,
            max: 100,
            defaultValue: 0,
            onChanged: (v) => controller.updateColor(c.copyWith(exposure: v)),
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
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white54),
                tooltip: l10n.resetColorTooltip,
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
