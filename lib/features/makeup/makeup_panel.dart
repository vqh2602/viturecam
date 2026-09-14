import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/beauty_slider.dart';
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

    String activeCategoryName;
    switch (subTool) {
      case 'blush':
        activeCategoryName = 'Blush';
        break;
      case 'eyebrow':
        activeCategoryName = 'Eyebrow';
        break;
      case 'eyeliner':
        activeCategoryName = 'Eyeliner';
        break;
      case 'eyeshadow':
        activeCategoryName = 'Eyeshadow';
        break;
      case 'lip':
      default:
        activeCategoryName = 'Lipstick';
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Category Selector + Opacity Slider
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 14),
              // Category Pills
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
                    for (final cat in categories)
                      GestureDetector(
                        onTap: () => controller.selectSubTool(cat['id'] as String),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: subTool == cat['id']
                                ? const Color(0xFFFF7597)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            cat['label'] as String,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: subTool == cat['id']
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: subTool == cat['id']
                                  ? Colors.white
                                  : Colors.white60,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Opacity Slider
              Expanded(
                child: activePreset != 'none'
                    ? BeautySlider(
                        label: '$activeCategoryName Intensity',
                        value: activeOpacity,
                        defaultValue: 60,
                        onChanged: onOpacityChanged,
                      )
                    : Center(
                        child: Text(
                          'Select a $activeCategoryName color below',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Colors.white10),

        // Row 2: Reset Button + Style Chips (if Lip or Blush) + Swatches Bar
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white54),
                tooltip: 'Reset Makeup',
                onPressed: m.isModified ? () => controller.resetMakeup() : null,
              ),

              // Style Chips for Lipstick, Blush, Eyebrow, Eyeliner, Eyeshadow
              if (subTool == 'lip') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildStyleSelector(
                  options: MakeupPresets.lipStyles,
                  selectedId: m.lipStyle,
                  onSelect: (id) => controller.updateMakeup(m.copyWith(lipStyle: id)),
                ),
              ] else if (subTool == 'blush') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildStyleSelector(
                  options: MakeupPresets.blushStyles,
                  selectedId: m.blushStyle,
                  onSelect: (id) => controller.updateMakeup(m.copyWith(blushStyle: id)),
                ),
              ] else if (subTool == 'eyebrow') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildStyleSelector(
                  options: MakeupPresets.eyebrowStyles,
                  selectedId: m.eyebrowStyle,
                  onSelect: (id) => controller.updateMakeup(m.copyWith(eyebrowStyle: id)),
                ),
              ] else if (subTool == 'eyeliner') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildStyleSelector(
                  options: MakeupPresets.eyelinerStyles,
                  selectedId: m.eyelinerStyle,
                  onSelect: (id) => controller.updateMakeup(m.copyWith(eyelinerStyle: id)),
                ),
              ] else if (subTool == 'eyeshadow') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildStyleSelector(
                  options: MakeupPresets.eyeshadowStyles,
                  selectedId: m.eyeshadowStyle,
                  onSelect: (id) => controller.updateMakeup(m.copyWith(eyeshadowStyle: id)),
                ),
              ],

              const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),

              // Preset Color Swatches List
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  itemCount: activeOptions.length,
                  itemBuilder: (context, idx) {
                    final opt = activeOptions[idx];
                    final isSel = opt.id == activePreset;

                    return GestureDetector(
                      onTap: () => onSelectPreset(opt.id),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
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
                                  ? const Icon(Icons.block, size: 12, color: Colors.white54)
                                  : null,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              opt.name,
                              style: TextStyle(
                                fontSize: 10,
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStyleSelector({
    required List<MakeupStyleOption> options,
    required String selectedId,
    required ValueChanged<String> onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF222227),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opt in options)
            GestureDetector(
              onTap: () => onSelect(opt.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: selectedId == opt.id ? const Color(0xFFFF7597) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt.icon,
                      size: 13,
                      color: selectedId == opt.id ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      opt.name,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: selectedId == opt.id ? FontWeight.w600 : FontWeight.w400,
                        color: selectedId == opt.id ? Colors.white : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
