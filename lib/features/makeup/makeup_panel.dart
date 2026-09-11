import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/beauty_slider.dart';
import '../../widgets/tool_button.dart';
import '../camera/camera_controller.dart';
import 'makeup_settings.dart';

class MakeupPanel extends ConsumerWidget {
  const MakeupPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final m = state.makeup;
    final subTool = state.activeSubTool;

    final categories = [
      {'id': 'lip', 'label': 'Lipstick', 'icon': Icons.brush},
      {'id': 'blush', 'label': 'Blush', 'icon': Icons.bubble_chart},
      {'id': 'eyebrow', 'label': 'Eyebrow', 'icon': Icons.gesture},
      {'id': 'eyeliner', 'label': 'Eyeliner', 'icon': Icons.edit},
      {'id': 'eyeshadow', 'label': 'Eyeshadow', 'icon': Icons.palette},
    ];

    List<MakeupOption> activeOptions;
    String activePreset;
    double activeOpacity;
    ValueChanged<String> onSelectPreset;
    ValueChanged<double> onOpacityChanged;

    switch (subTool) {
      case 'blush':
        activeOptions = MakeupPresets.blushOptions;
        activePreset = m.blushPreset;
        activeOpacity = m.blushOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(blushPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(blushOpacity: op));
        break;
      case 'eyebrow':
        activeOptions = MakeupPresets.eyebrowOptions;
        activePreset = m.eyebrowPreset;
        activeOpacity = m.eyebrowOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(eyebrowPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(eyebrowOpacity: op));
        break;
      case 'eyeliner':
        activeOptions = MakeupPresets.eyelinerOptions;
        activePreset = m.eyelinerPreset;
        activeOpacity = m.eyelinerOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(eyelinerPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(eyelinerOpacity: op));
        break;
      case 'eyeshadow':
        activeOptions = MakeupPresets.eyeshadowOptions;
        activePreset = m.eyeshadowPreset;
        activeOpacity = m.eyeshadowOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(eyeshadowPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(eyeshadowOpacity: op));
        break;
      case 'lip':
      default:
        activeOptions = MakeupPresets.lipOptions;
        activePreset = m.lipPreset;
        activeOpacity = m.lipOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(lipPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(lipOpacity: op));
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Preset Swatches Bar
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: activeOptions.length,
            itemBuilder: (context, idx) {
              final opt = activeOptions[idx];
              final isSel = opt.id == activePreset;

              return GestureDetector(
                onTap: () => onSelectPreset(opt.id),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: opt.id == 'none' ? const Color(0xFF26262B) : opt.color,
                          border: Border.all(
                            color: isSel ? Colors.white : Colors.white24,
                            width: isSel ? 2 : 1,
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: (opt.id == 'none' ? Colors.white : opt.color).withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  )
                                ]
                              : null,
                        ),
                        child: opt.id == 'none'
                            ? const Icon(Icons.block, size: 14, color: Colors.white54)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opt.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSel ? Colors.white : Colors.white60,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Opacity Slider (visible if not none)
        if (activePreset != 'none')
          BeautySlider(
            label: 'Intensity',
            value: activeOpacity,
            defaultValue: 60,
            onChanged: onOpacityChanged,
          )
        else
          const SizedBox(height: 12),

        const Divider(height: 1, color: Colors.white10),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white54),
                tooltip: 'Reset Makeup',
                onPressed: m.isModified ? () => controller.resetMakeup() : null,
              ),
              const SizedBox(width: 4),
              for (final cat in categories)
                ToolButton(
                  label: cat['label'] as String,
                  icon: cat['icon'] as IconData,
                  isSelected: subTool == cat['id'],
                  isActive: m.isKeyActive(cat['id'] as String),
                  onTap: () => controller.selectSubTool(cat['id'] as String),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
