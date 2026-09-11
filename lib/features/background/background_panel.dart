import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/beauty_slider.dart';
import '../../widgets/tool_button.dart';
import '../camera/camera_controller.dart';

class BackgroundPanel extends ConsumerWidget {
  const BackgroundPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final bg = state.background;

    final modes = [
      {'id': 'none', 'label': 'None', 'icon': Icons.block},
      {'id': 'portrait_blur', 'label': 'Portrait Blur', 'icon': Icons.lens_blur},
      {'id': 'strong_blur', 'label': 'Strong Blur', 'icon': Icons.blur_circular},
      {'id': 'virtual_studio', 'label': 'Studio', 'icon': Icons.camera},
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bg.mode != 'none')
          BeautySlider(
            label: 'Blur Intensity',
            value: bg.blurIntensity,
            defaultValue: 50,
            onChanged: (v) => controller.updateBackground(bg.copyWith(blurIntensity: v)),
          )
        else
          const SizedBox(height: 14),
        const Divider(height: 1, color: Colors.white10),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white54),
                tooltip: 'Reset Background',
                onPressed: bg.isModified ? () => controller.resetBackground() : null,
              ),
              const SizedBox(width: 4),
              for (final m in modes)
                ToolButton(
                  label: m['label'] as String,
                  icon: m['icon'] as IconData,
                  isSelected: bg.mode == m['id'],
                  isActive: bg.mode == m['id'] && m['id'] != 'none',
                  onTap: () => controller.updateBackground(bg.copyWith(mode: m['id'] as String)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
